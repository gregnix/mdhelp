package require Tk
# (c) 2026 Gregor Ebbing -- MIT License (see ../../LICENSE)
package require mdstack::editorkit 0.2

package provide mdeditwidget 0.2

namespace eval mdeditwidget {
    namespace export create settext gettext setmode mode model setmodel getdocmodel configure cget widgets
    variable state
    array set state {}
}

proc mdeditwidget::create {path args} {
    variable state

    ttk::frame $path
    grid columnconfigure $path 0 -weight 1
    grid rowconfigure    $path 1 -weight 1

    # Toolbar
    set tb [ttk::frame $path.tb]
    ttk::button $tb.edit    -text "Edit"    -command [list mdeditwidget::setmode $path edit]
    ttk::button $tb.preview -text "Preview" -command [list mdeditwidget::setmode $path preview]
    ttk::button $tb.split   -text "Split"   -command [list mdeditwidget::setmode $path split]

    grid $tb.edit $tb.preview $tb.split -sticky w -padx 4 -pady 4
    grid columnconfigure $tb 3 -weight 1

    # Main kit
    set kit [mdstack::editorkit::create $path.kit]
    grid $tb  -row 0 -column 0 -sticky ew
    grid $kit -row 1 -column 0 -sticky nsew

    set state($path,tb)  $tb
    set state($path,kit) $kit

    mdeditwidget::configure $path {*}$args
    return $path
}

proc mdeditwidget::widgets {path} {
    variable state
    set d [mdstack::editorkit::widgets $state($path,kit)]
    dict set d toolbar $state($path,tb)
    dict set d kit $state($path,kit)
    return $d
}

proc mdeditwidget::configure {path args} {
    variable state
    if {[llength $args] == 0} { return }
    mdstack::editorkit::configure $state($path,kit) {*}$args
}

proc mdeditwidget::cget {path option} {
    variable state
    return [mdstack::editorkit::cget $state($path,kit) $option]
}

proc mdeditwidget::settext {path markdown} {
    variable state
    mdstack::editorkit::settext $state($path,kit) $markdown
}

proc mdeditwidget::gettext {path} {
    variable state
    return [mdstack::editorkit::gettext $state($path,kit)]
}

proc mdeditwidget::setmode {path m} {
    variable state
    mdstack::editorkit::setmode $state($path,kit) $m
}

proc mdeditwidget::mode {path} {
    variable state
    return [mdstack::editorkit::mode $state($path,kit)]
}

proc mdeditwidget::model {path} {
    variable state
    return [mdstack::editorkit::model $state($path,kit)]
}

proc mdeditwidget::setmodel {path m} {
    variable state
    mdstack::editorkit::setmodel $state($path,kit) $m
}

proc mdeditwidget::getdocmodel {path} {
    variable state
    return [mdstack::editorkit::getdocmodel $state($path,kit)]
}
