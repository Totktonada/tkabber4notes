namespace eval ifaces::gui {
# TODO: need here, or only in ::plugins::notes?
#    package require xmpp::private::notes
#    package require msgcat
}

# TODO: variable lbox in all proc, where $lbox used, changed this variable in create_nptes_tab. Also: conn_menu.

proc ifaces::gui::load {} {
    hook::add plugins_notes_changed_connections_hook \
        [namespace current]::changed_connections
    hook::add plugins_notes_changed_current_connection_hook \
        [namespace current]::changed_current_connection
    hook::add plugins_notes_changed_note_hook \
        [namespace current]::changed_note

    hook::add finload_hook [namespace current]::setup_menu

    setup_menu
}

proc ifaces::gui::unload {} {
    desetup_menu
    destroy_win .notes
#TODO: destroy edit_note window

    hook::remove finload_hook [namespace current]::setup_menu

    hook::remove plugins_notes_changed_connections_hook \
        [namespace current]::changed_connections
    hook::remove plugins_notes_changed_current_connection_hook \
        [namespace current]::changed_current_connection
    hook::remove plugins_notes_changed_note_hook \
        [namespace current]::changed_note

}

proc ifaces::gui::changed_connections {} {
    if {![winfo exists .notes]} return

    update_connections_menu
}

proc ifaces::gui::changed_current_connection {} {
    if {![winfo exists .notes]} return

# TODO: drop all editboxes
    update_connections_menu_label
    update_lbox
}

proc ifaces::gui::changed_note {idx new_note} {
    if {![winfo exists .notes]} return

    update_lbox_at $idx $new_note
}

####################################################################
# GUI

proc ifaces::gui::setup_menu {} {
    catch {
        set m [.mainframe getmenu plugins]

        $m add command -label [::msgcat::mc "Notes"] \
            -command [list [namespace current]::open_window]
    }
}

proc ifaces::gui::desetup_menu {} {
    catch {
        set m [.mainframe getmenu plugins]
        set ind [$m index [::msgcat::mc "Notes"]]

        $m delete $ind
    }
}

proc ifaces::gui::open_window {} {
    set w .notes

    if {[winfo exists $w]} {
        raise_win $w
        return
    }

#    if {[llength [::plugins::notes::connections]] == 0} return

    add_win $w -title [::msgcat::mc "Notes"] \
        -tabtitle [::msgcat::mc "Notes"] \
        -class Notes \
        -raise 1

    create_notes_tab $w

# For storing notes after close tab uncomment next line.
#    bind $w <Destroy> +[list [namespace current]::store_all_notes]
# Now: store notes immediately after edit.
}

proc ifaces::gui::create_notes_tab {w} {
# ==== Button box ====
    set tools [frame $w.tools -borderwidth 5]
    pack $tools -side top -fill y -anchor w

# ==== Buttons ====
    set new_button [button $tools.new_button -text [::msgcat::mc "New note"] \
        -command [list [namespace current]::edit_note end]]
    pack $new_button -anchor w -side left
    set delete_button [button $tools.delete_button -text [::msgcat::mc "Delete note"] \
        -command [list [namespace current]::delete_focused_note]]
    pack $delete_button -anchor w -side left

# ==== List of connections ====
    set conn_button [menubutton $tools.conn_button \
        -menu $tools.conn_button.menu]
    set conn_menu [menu $conn_button.menu -tearoff 0]
    update_connections_menu
    update_connections_menu_label
    pack $conn_button -anchor w -side left
# TODO: from menubutton to OptionMenu?
#    set conn_menu [OptionMenu $tools.conn_menu [::plugins::notes::connections]]

# ==== lbox frame ====
    set lbox_frame [frame $w.lbox_frame]
    pack $lbox_frame -side left -fill both -expand true -anchor w

# ==== lbox frame scrolled widget ====
    grid columnconfigure $lbox_frame 0 -weight 1
    set sw [ScrolledWindow $lbox_frame.sw]

    set lbox [listbox $lbox_frame.lbox -takefocus 1 -exportselection 0]
    update_lbox
    focus $lbox

# ==== Bind ====
    # From ${PATH_TO_TKABBER}/plugins/chat/histool.tcl
    # Workaround for a bug in listbox (can't get focus on mouse clicks):
    bind Listbox <Button-1> {+ if {[winfo exists %W]} {focus %W}}

    bind $lbox <Double-Button-1> [namespace code {
        edit_note [%W nearest %y]
    }]

    bind $lbox <Return> [namespace code {
        edit_note [%W index active]
    }]

# ==== Other ====
    $sw setwidget $lbox
    grid $sw -sticky news
    grid rowconfigure $lbox_frame 0 -weight 1
}

proc ifaces::gui::update_connections_menu_label {} {
    if {![winfo exists .notes]} return

    set conn_button .notes.tools.conn_button
    $conn_button configure -text [::plugins::notes::get_current_connection_name]
}

proc ifaces::gui::update_connections_menu {} {
    puts "called update_connections_menu"
    set conn_menu .notes.tools.conn_button.menu
    $conn_menu delete 0 end
    puts "update_connections_menu: deleted items"

    foreach conn [::plugins::notes::connections] {
#TODO: replace connection_jid with proc similar to ::plugins::notes::get_current_connection_name
        $conn_menu add command \
            -label [connection_jid $conn] \
            -command [namespace code [format {
                ::plugins::notes::set_current_xlib %1$s
            } $conn]]
    }
}

proc ifaces::gui::delete_focused_note {} {
#TODO: ask "Are you sure..?".
    if {[llength [plugins::notes::connections]] == 0} return

    set lbox .notes.lbox_frame.lbox
    set idx [$lbox index active]
    ::plugins::notes::set_note $idx {}
}

proc ifaces::gui::edit_note {idx args} {
    if {[llength [plugins::notes::connections]] == 0} return

    if {[cequal $idx end]} {
        set title ""
        set tags_str ""
        set text ""
    } else {
        set source_note [::plugins::notes::get_note $idx]
        ::xmpp::private::notes::split $source_note title -> text tags_str
    }

    set dialog_w .edit_note
    catch { destroy $dialog_w }
    set dialog_w [Dialog $dialog_w -title [::msgcat::mc "Edit note"] \
        -separator 1 \
        -anchor e \
        -default 0 \
        -cancel 1 \
        -modal none]

    set dialog_frame [$dialog_w getframe]
    grid columnconfigure $dialog_frame 1 -weight 1

    label $dialog_frame.ltitle -text [::msgcat::mc "Title:"]
    [entry $dialog_frame.title] insert end $title
    label $dialog_frame.ltags  -text [::msgcat::mc "Tags:"]
    [entry $dialog_frame.tags] insert end $tags_str

    set sw [ScrolledWindow $dialog_frame.sw]
    [textUndoable $dialog_frame.text -wrap word] insert end $text
    $sw setwidget $dialog_frame.text

    grid $dialog_frame.ltitle -row 0 -column 0 -sticky nw
    grid $dialog_frame.title  -row 0 -column 1 -sticky ew
    grid $dialog_frame.ltags  -row 1 -column 0 -sticky nw
    grid $dialog_frame.tags   -row 1 -column 1 -sticky ew
    grid $sw -row 2 -column 0 -columnspan 2 -sticky nw

    $dialog_w add -text [::msgcat::mc "Ok"] \
        -command [list [namespace current]::edit_note_cmd_ok $dialog_w $idx]
    $dialog_w add -text [::msgcat::mc "Cancel"] \
        -command [list destroy $dialog_w]

# Next 3 commands from ${PATH_TO_TKABBER}/plugins/roster/annotations.tcl (annotations::show_dialog).
    bind $dialog_frame.text <Control-Key-Return> "[double% $dialog_w] invoke default
                                       break"
    bind $dialog_w <Key-Return> { }
    bind $dialog_w <Control-Key-Return> "[double% $dialog_w] invoke default
                                  break"

    $dialog_w draw $dialog_frame.title
}

proc ifaces::gui::edit_note_cmd_ok {dialog_w idx} {
    set dialog_frame [$dialog_w getframe]

    set title [$dialog_frame.title get]
    set tags_str [$dialog_frame.tags get]
    set text [$dialog_frame.text get 0.0 "end -1 char"]

    set new_note [::xmpp::private::notes::create $title "" $text $tags_str]

    ::plugins::notes::set_note $idx $new_note
    destroy $dialog_w
}

proc ifaces::gui::update_lbox_at {idx new_note} {
    set lbox .notes.lbox_frame.lbox

    if {![cequal $idx end]} {
        $lbox delete $idx $idx
    }

    if {[llength $new_note] != 0} {
        $lbox insert $idx [get_short_string $new_note]
    }

    update_lbox_selection $idx
}

proc ifaces::gui::update_lbox {} {
    set lbox .notes.lbox_frame.lbox

    $lbox delete 0 end

    foreach note [::plugins::notes::get_notes] {
        $lbox insert end [get_short_string $note]
    }

    update_lbox_selection end
}

proc ifaces::gui::update_lbox_selection {idx} {
    set lbox .notes.lbox_frame.lbox

    $lbox selection clear 0 end
    $lbox selection set $idx
    $lbox activate $idx
}

####################################################################
# Utils

proc ifaces::gui::get_short_string {note} {
    ::xmpp::private::notes::split $note title -> text tags_str

    set short_string $title

    if {[string length $short_string] == 0} {
        set short_string $text
    }

    if {[string length $short_string] == 0} {
        set short_string {[Title and text is empty]}
    }

# TODO: Need?
if {0} {
    set max_length 30
    if {[string length $short_string] > $max_length} {
        set short_string "[string range $short_string 0 [expr $max_length - 4]]..."
    }
}

    return $short_string
}
