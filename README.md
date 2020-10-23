# MoeStreamer

A tiny macOS app that sits in the menubar, to stream music from [LISTEN.moe](https://listen.moe). It also lets you play local playlists from iTunes (or Music.app — same thing).

## Features

1. Streaming from LISTEN.moe, including (un)favouriting when logged in
2. Playback from local iTunes (Music.app) library
3. Search for local music
4. *ALWAYS* overrides media keys (F7-F9, or touchbar buttons) when the app is open.

When logging in to LISTEN.moe, the account password is stored in the macOS Keychain.

## Screenshots

Here's how it looks like in the menubar:
<div style="text-align: center">
<img src="screenshots/one.png" width="600px" />
</div>

Search view:
<div style="text-align: center">
<img src="screenshots/two.png" width="300px" />
</div>

Settings view:
<div style="text-align: center">
<img src="screenshots/three.png" width="300px" />
</div>


## Keyboard Shortcuts
At the moment, these shortcuts cannot be customised.

|  function   |              key               |
|-------------|--------------------------------|
|play / pause | <kbd>K</kbd>, <kbd>space</kbd> |
| next song   |          <kbd>L</kbd>          |
| (un)mute    |          <kbd>M</kbd>          |
|   search    |          <kbd>/</kbd>          |
|(un)favourite|          <kbd>F</kbd>          |


## Building
```
$ carthage update --platform macos
$ xcodebuild
```

Alternatively, open the Xcode project and build it there (you still need to run `carthage`).

## License

Contributions from `my_cat_is_ugly` on Twitch.

Code is licensed under the Apache License Version 2.
Icons are from Google's [material.io](https://material.io/resources/icons/), which are similarly licensed.

App icon is gotten from [here](https://old.reddit.com/r/pouts/comments/d1p2ua)
