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

### macOS 11 (Bug Sir) or higher

Here, you should use CocoaPods to install VLCKit:
 
```
pod install
```

Then, open `MoeStreamer.xcworkspace` instead of `xcproj` (because that's how CocoaPods works...). Once the VLCKit people release 3.3.18 with the fix for macOS 11 I'll get rid of cocoapods.


### macOS Catalina (10.15) or lower
You can install VLCKit via Carthage:

```
carthage update --platform macos
```

However, you need to open the project in Xcode, and add `VLCKit.framework`, under the *Frameworks, Libraries, and Embedded Content* list in the **Target Settings**. Choose "Embed and Sign".

Either way, after installing the dependencies, either run `xcodebuild` from the terminal, or open Xcode 
and build it from there. 

## License

Contributions from `my_cat_is_ugly` on Twitch.

Code is licensed under the Apache License Version 2.
Icons are from Google's [material.io](https://material.io/resources/icons/), which are similarly licensed.

App icon is gotten from [here](https://old.reddit.com/r/pouts/comments/d1p2ua)
