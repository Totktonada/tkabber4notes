package require xmpp::private

package provide xmpp::private::notes 0.1

namespace eval ::xmpp::private::notes {
    namespace export create split store retrieve serialize deserialize
}

proc ::xmpp::private::notes::create {title tags text {tags_str ""}} {
    if {![string equal $tags_str ""]} {
        set tags [::split $tags_str " "]
    }
    return [list title $title tags $tags text $text]
}

proc ::xmpp::private::notes::split {note titleVar tagsVar textVar \
        {tags_strVar ""}} {
    upvar 1 $titleVar title $tagsVar tags $textVar text

    set title ""
    set tags {}
    set text ""

    foreach {key value} $note {
        switch -- $key {
            title -
            tags -
            text {
                set $key $value
            }
        }
    }

    if {![string equal $tags_strVar ""]} {
        upvar 1 $tags_strVar tags_str
        set tags_str [join $tags " "]
    }

    return
}

proc ::xmpp::private::notes::retrieve {xlib args} {
    set commands {}
    set timeout 0

    foreach {key val} $args {
        switch -- $key {
            -timeout {
                set timeout $val
            }
            -command {
                set commands [list $val]
            }
            default {
                return -code error \
                   [::msgcat::mc "Illegal option \"%s\"" $key]
            }
        }
    }

    set id [::xmpp::private::retrieve $xlib \
        [list [::xmpp::xml::create storage \
        -xmlns "http://miranda-im.org/storage#notes"]] \
        -command [namespace code [list ProcessRetrieveAnswer $commands]] \
        -timeout $timeout]
    return $id
}

proc ::xmpp::private::notes::ProcessRetrieveAnswer {commands status xml} {
    if {[llength $commands] == 0} return

    if {![string equal $status ok]} {
        uplevel #0 [lindex $commands 0] [list $status $xml]
    }

    uplevel #0 [lindex $commands 0] [list ok [deserialize $xml]]
    return
}

proc ::xmpp::private::notes::deserialize {xml} {
    set notes {}

    foreach xmldata $xml {
    ::xmpp::xml::split $xmldata tag xmlns attrs cdata subels

    if {[string equal $xmlns "http://miranda-im.org/storage#notes"]} {
        foreach note $subels {
            ::xmpp::xml::split $note n_tag n_xmlns n_attrs n_cdata n_subels

            set title ""
            set tags_str [::xmpp::xml::getAttr $n_attrs "tags"]
            set text ""

            foreach n_subel $n_subels {
                ::xmpp::xml::split $n_subel nc_tag nc_xmlns nc_attrs nc_cdata nc_subels
                switch -- $nc_tag {
                    title -
                    text {
                        set $nc_tag $nc_cdata
                    }
                }
            }

            lappend notes [::xmpp::private::notes::create $title "" $text $tags_str]
            }
        }
    }

    return $notes
}

proc ::xmpp::private::notes::serialize {notes} {
    set tags {}
    foreach note $notes {
        ::xmpp::private::notes::split $note title -> text tags_str

        lappend tags [ \
            ::xmpp::xml::create "note" \
                -attrs [list "tags" $tags_str] \
                -subelement [ \
                    ::xmpp::xml::create "title" \
                        -cdata $title \
                ] \
                -subelement [ \
                    ::xmpp::xml::create "text" \
                        -cdata $text \
                ] \
        ]
    }

    return [::xmpp::xml::create storage \
        -xmlns "http://miranda-im.org/storage#notes" \
        -subelements $tags]
}

proc ::xmpp::private::notes::store {xlib notes args} {
    set commands {}
    set timeout 0

    foreach {key val} $args {
        switch -- $key {
            -timeout {
                set timeout $val
            }
            -command {
                set commands [list $val]
            }
            default {
                return -code error \
                   [::msgcat::mc "Illegal option \"%s\"" $key]
            }
        }
    }

    set id [::xmpp::private::store $xlib \
        [list [serialize $notes]] \
        -command [namespace code [list ProcessStoreAnswer $commands]] \
        -timeout $timeout]
    return $id
}

proc ::xmpp::private::notes::ProcessStoreAnswer {commands status xml} {
    if {[llength $commands] > 0} {
        uplevel #0 [lindex $commands 0] [list $status $xml]
    }
    return
}
