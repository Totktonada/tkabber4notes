namespace eval notes {
    set scriptdir [file dirname [info script]]
    lappend ::auto_path $scriptdir
    package require xmpp::private::notes

    package require msgcat
    ::msgcat::mcload [file join [file dirname [info script]] msgs]

    if {![::plugins::is_registered notes]} {
        ::plugins::register notes \
            -namespace [namespace current] \
            -source [info script] \
            -description [::msgcat::mc "Whether the Notes plugin is loaded."] \
            -loadcommand [namespace code load] \
            -unloadcommand [namespace code unload]
        return
    }
}

####################################################################
# Load/unload

proc notes::load {} {
    variable scriptdir
# We need initializing it?
    free_all_notes

    set ifaces_dir [file join $scriptdir ifaces]
    foreach iface_file [glob -nocomplain -directory "$ifaces_dir" "*.tcl"] {
# TODO: We need source $iface_file?
        source $iface_file
        set iface_name [file tail [file rootname $iface_file]]
        eval ifaces::${iface_name}::load
    }

    source [file join $scriptdir ie.tcl]

    hook::add disconnected_hook [namespace current]::disconnected
    hook::add connected_hook [namespace current]::connected

    request_all_notes
}

proc notes::unload {} {
    variable scriptdir

# TODO: think about create list of ifaces on load (in notes::load) and unload them by this list
    set ifaces_dir [file join $scriptdir ifaces]
    foreach iface_file [glob -nocomplain -directory "$ifaces_dir" "*.tcl"] {
        set iface_name [file tail [file rootname $iface_file]]
        catch { eval ifaces::${iface_name}::unload }
    }


    hook::remove disconnected_hook [namespace current]::disconnected
    hook::remove connected_hook [namespace current]::connected

    free_all_notes
}

####################################################################
# Connect/disconnect

proc notes::disconnected {xlib} {
    free_notes $xlib
}

proc notes::connected {xlib} {
    request_notes $xlib
}

####################################################################
# Request notes

proc notes::request_notes {xlib} {
    ::xmpp::private::notes::retrieve $xlib \
        -command [list [namespace current]::process_notes $xlib]
}

proc notes::process_notes {xlib status noteslist} {
    variable notes
    variable current_xlib

    if {$status != "ok"} return

 #TODO( maybe not sending event?
    free_notes $xlib
#)
    set notes($xlib) $noteslist
    hook::run plugins_notes_changed_connections_hook

    if {![info exist current_xlib]} {
        set_current_xlib $xlib
    }
}

proc notes::request_all_notes {} {
    # Request notes for all established connections.
    foreach conn [::connections] {
        request_notes $conn
    }
}

####################################################################
# Store notes

proc notes::store_notes {xlib} {
    variable notes

    ::xmpp::private::notes::store $xlib $notes($xlib) \
        -command [list [namespace current]::store_notes_result]
}

proc notes::store_notes_result {res child0} {
# TODO
}

proc notes::store_all_notes {} {
    variable notes

    foreach conn [connections] {
        store_notes $conn
    }
}

####################################################################
# Free notes

#proc notes::free_notes {xlib {send_event 1}} {#TODO: need? 
proc notes::free_notes {xlib} {
    variable notes
    variable current_xlib

    array unset notes $xlib
    hook::run plugins_notes_changed_connections_hook
# TODO: possibly, comfortable variant:
# hook::run plugins_notes_changed_connections_hook $xlib
# or
# hook::run plugins_notes_changed_connections_hook [connections]
# also, see all proc, where run this hook and all proc, added to this hook in gui.tcl

    if {[info exists current_xlib]} {
        if {[cequal $current_xlib $xlib]} {
            if {[llength [connections]] > 0} {
                set_current_xlib [lindex [connections] 0]
            } else {
                unset_current_xlib
            }
#TODO: need unset current_xlib if {![cequal $current_xlib $xlib]} ?
        }
    }
}

proc notes::free_all_notes {} {
    variable notes

    unset_current_xlib
    array unset notes
    hook::run plugins_notes_changed_connections_hook
}

####################################################################
# Other utils

# We know about connections, which relate to not empty notes list
proc notes::connections {} {
    variable notes

    return [lsort [array names notes]]
}

#proc notes::is_current_xlib {xlib} {}

####################################################################
# Interaction with ifaces
# All proc work with current_xlib

proc notes::set_current_xlib {xlib} {
    variable current_xlib

    set current_xlib $xlib
    hook::run plugins_notes_changed_current_connection_hook
}

proc notes::unset_current_xlib {} {
    variable current_xlib

    if {![info exists current_xlib]} return

    unset current_xlib
    hook::run plugins_notes_changed_current_connection_hook
}

proc notes::get_current_connection_name {} {
    variable current_xlib

    if {[info exists current_xlib]} {
        set connection_name [connection_jid $current_xlib]
    } else {
        set connection_name [::msgcat::mc "Disconnected"]
    }

    return $connection_name
}

proc notes::get_note {idx {search_tags {}}} {
    variable notes
    variable current_xlib

#    if {![info exists current_xlib]} return # Hm... TODO: think.

    return [lindex [get_notes $search_tags] $idx]
}

proc notes::set_note {real_idx idx new_note} {
    variable notes
    variable current_xlib

    if {![info exists current_xlib]} return

    if {[llength $new_note] == 0} {
        set notes($current_xlib) [lreplace $notes($current_xlib) $real_idx $real_idx]
    } else {
        if {[cequal $real_idx end]} {
            lappend notes($current_xlib) $new_note
        } else {
            lset notes($current_xlib) $real_idx $new_note
        }
    }

    store_notes $current_xlib
    hook::run plugins_notes_changed_note_hook $idx $new_note
}

proc notes::filter {note search_tags} {
    ::xmpp::private::notes::split $note title tags text tags_str

    foreach search_tag $search_tags {
        if {[lsearch -exact $tags $search_tag] < 0} {
            return 0
        }
    }

    return 1
}

proc notes::get_notes {{search_tags {}}} {
    variable notes
    variable current_xlib

    set current_notes {}

    if {![info exists current_xlib]} {
        return $current_notes
    }

    if {[llength $search_tags] == 0} {
        set current_notes $notes($current_xlib)
    } else {
        foreach note $notes($current_xlib) {
            if {[filter $note $search_tags]} {
                lappend current_notes $note
            }
        }
    }

    return $current_notes
}

# TODO: replace ugly get_real_index with notes id.
proc notes::get_real_index {idx {search_tags {}}} {
    if {[cequal $idx end]} {
        return end
    }

    set real_index 0
    foreach note [get_notes] {
        if {[filter $note $search_tags]} {
            incr idx -1
        }
        if {$idx < 0} {
            return $real_index
        }
        incr real_index
    }

    return -1
}
