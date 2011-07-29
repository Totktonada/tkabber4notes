namespace eval ie {
# TODO:
if {0} {
    variable version 1.0

    if {![file exists $options(notes_dir)]} {
        file mkdir $options(notes_dir)

        # Storing version for possible future conversions
        set fd [open [file join $options(notes_dir) version] w]
        puts $fd $version
        close $fd
    }
}
}

####################################################################
# Mapping symbols from ${PATH_TO_TKABBER}/plugins/chat/logger.tcl

proc ie::str_to_log {str} {
    return [string map {\\ \\\\ \r \\r \n \\n} $str]
}

proc ie::log_to_str {str} {
    return [string map {\\\\ \\ \\r \r \\n \n} $str]
}

####################################################################
# Export

proc ie::export {notes_file {search_tags {}}} {
    set fd [open $notes_file w]
    foreach note [::plugins::notes::get_notes $search_tags] {
        puts $fd [str_to_log $note]
    }
    close $fd
}
