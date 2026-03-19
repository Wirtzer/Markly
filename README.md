# MacDown v2

MacDown v2 is an open source Markdown editor for macOS, based on [Mou](http://mouapp.com) by Chen Luo and the original [MacDown](https://github.com/MacDownApp/macdown) by Tzu-ping Chung. We saw a lot of room for updates and improvements, so we created our own version.

## What's New

- **Default View Mode** — Choose whether files open in Editor Only, Preview Only, or Both via Preferences > General
- **Toolbar View Switcher** — Quickly toggle between editor, preview, and split view from the toolbar

## Install

Clone, build, and run:

    git clone https://github.com/Wirtzer/macdownv2.git
    cd macdownv2
    git submodule update --init --recursive
    pod install
    open MacDown.xcworkspace

Then build and run in Xcode.

## Screenshot

![screenshot](assets/screenshot.png)

## License

MacDown v2 is released under the terms of the MIT License. See the `LICENSE` directory for details.

The following editor themes and CSS files are from [Mou](http://mouapp.com), courtesy of Chen Luo:

* Mou Fresh Air / Fresh Air+
* Mou Night / Night+
* Mou Paper / Paper+
* Tomorrow / Tomorrow Blue / Tomorrow+
* Writer / Writer+
* Clearness / Clearness Dark
* GitHub / GitHub2
