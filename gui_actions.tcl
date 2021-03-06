namespace eval gui_actions {
# TODO: need here, or only in ::plugins::notes?
#    package require msgcat
}

proc gui_actions::load {} {
    hook::add chat_win_popup_menu_hook [namespace current]::selection_popup 90
}

proc gui_actions::unload {} {
    hook::remove chat_win_popup_menu_hook [namespace current]::selection_popup 90
}

proc gui_actions::selection_popup {m W X Y x y} {
    if {[llength [$W tag ranges sel]] == 0 || \
        [llength [plugins::notes::connections]] == 0} \
    {
        set state disabled
    } else {
        set state normal
    }

    $m add command -label [::msgcat::mc "Copy selection to new note"] \
        -command [list [namespace current]::CopySelection $W] \
        -state $state
}

proc gui_actions::CopySelection {cw} {
    if {$cw eq "."} {
        set cw [get_chatwin]
        if {$cw eq ""} return
    }

    set sel [$cw tag ranges sel]
    if {$sel eq ""} return

    set text [$cw get [lindex $sel 0] [lindex $sel 1]]

#    ::plugins::notes::set_note end end $new_note # Add note immediately.
    ::plugins::notes::ifaces::gui::edit_note end \
        -text $text
}
