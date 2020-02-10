// MainView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import SwiftUI
import Foundation

struct MainView : View
{
	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	@State var isPlaying: Bool = false
	@State var volume: Double = Settings.get(key: "volume", default: 50)

	@State var showingSettings: Bool = false
	@State var showingLog: Bool = false

	@State var musicCon: ServiceController

	@ObservedObject	var wrapper: ViewWrapper
	@ObservedObject var audioCon: AudioController

	@Binding var parentPopover: NSPopover


	init(popover: Binding<NSPopover>)
	{
		let vw = ViewWrapper()
		let con = ListenMoeController(activityView: vw)

		self._wrapper = ObservedObject(initialValue: vw)
		self._audioCon = ObservedObject(initialValue: con.audioController())

		self._musicCon = State(initialValue: con)

		self._parentPopover = popover
	}

    var body: some View {
		VStack() {
			ZStack(alignment: .topTrailing) {
				HStack() {
					Image(nsImage: self.musicCon.getCurrentSong()?.album.1 ?? #imageLiteral(resourceName: "NoCoverArt"))
						.resizable()
						.shadow(radius: 5)
						.frame(width: 96, height: 96, alignment: .leading)
						.padding(.trailing, 8)

					VStack(alignment: .leading) {

						VStack(alignment: .leading) {
							Text(self.musicCon.getCurrentSong()?.title ?? "not playing")
								.multilineTextAlignment(.leading)
								.padding(.bottom, 4)

							Text(self.musicCon.getCurrentSong()?.artists.joined(separator: ", ") ?? "—")
								.multilineTextAlignment(.leading)
						}.frame(height: 60)

						HStack(spacing: 2) {
							// play/pause button
							Button(action: {
								self.audioCon.setVolume(volume: Int(self.volume))
								if !self.isPlaying
								{
									self.audioCon.play()
									self.musicCon.start()
								}
								else
								{
									self.audioCon.pause()
									self.musicCon.pause()
								}

								self.isPlaying.toggle()
							}) {
								Image(nsImage: self.isPlaying ? #imageLiteral(resourceName: "Pause") : #imageLiteral(resourceName: "Play"))
									.resizable()
									.frame(width: 24, height: 24)
									.foregroundColor(colourScheme == .light ? .black : .white)
							}
							.buttonStyle(PlainButtonStyle())

							// favourite/unfavourite button
							Button(action: {
								self.musicCon.toggleFavourite()
							}) {
								Image(nsImage: (self.musicCon.getCurrentSong()?.isFavourite ?? .No).icon())
									.resizable()
									.frame(width: 24, height: 24)
									.foregroundColor(colourScheme == .light ? .black : .white)
							}
							.buttonStyle(PlainButtonStyle())

							// mute/unmute button
							Button(action: {
								self.audioCon.toggleMute()
							}) {
								Image(nsImage: self.audioCon.isMuted() ? #imageLiteral(resourceName: "Mute") : #imageLiteral(resourceName: "VolUp"))
									.resizable()
									.frame(width: 24, height: 24)
									.foregroundColor(colourScheme == .light ? .black : .white)
							}
							.buttonStyle(PlainButtonStyle())

							VolumeSlider(value: Binding(get: { self.volume }, set: { x in
								self.volume = x
								self.audioCon.setVolume(volume: Int(x))
							})).padding(.leading, 4)

						}
						.padding(.bottom, 8)
					}
				}.padding(.top, 16)

				VStack(alignment: .trailing, spacing: 4) {
					Button(action: {
						self.musicCon.stop()
						NSApplication.shared.terminate(self)
					}) {
						Image(nsImage: #imageLiteral(resourceName: "Close"))
							.resizable()
							.frame(width: 16, height: 16)
							.foregroundColor(colourScheme == .light ? .black : .white)
					}
					.buttonStyle(PlainButtonStyle())
					.padding(.top, 4)

					Button(action: {
						self.showingSettings.toggle()
						self.showingLog = false
					}) {
						Image(nsImage: #imageLiteral(resourceName: "Settings"))
							.resizable()
							.frame(width: 16, height: 16)
							.foregroundColor(colourScheme == .light ? .black : .white)
					}
					.buttonStyle(PlainButtonStyle())

					Button(action: {
						self.showingLog.toggle()
						self.showingSettings = false
					}) {
						Image(nsImage: #imageLiteral(resourceName: "Log"))
							.resizable()
							.frame(width: 16, height: 16)
							.foregroundColor(colourScheme == .light ? .black : .white)
					}
					.buttonStyle(PlainButtonStyle())

					Spacer()

					HStack(spacing: 2) {
						if !self.wrapper.status.isEmpty
						{
							Text(self.wrapper.status)
								.font(Font.system(size: 10))
								.transition(.opacity)
								.padding(.trailing, 4)
						}

						if self.wrapper.spinning > 0
						{
							ActivityIndicator()
								.frame(width: 16, height: 16)
						}

						Button(action: {
							self.musicCon.refresh()
						}) {
							Image(nsImage: #imageLiteral(resourceName: "Refresh"))
								.resizable()
								.frame(width: 16, height: 16)
								.foregroundColor(colourScheme == .light ? .black : .white)
						}
						.buttonStyle(PlainButtonStyle())
					}
					.padding(.bottom, 4)
				}
				.padding(.trailing, -12)
			}
			.frame(width: 320, height: 128, alignment: .leading)
			.padding(.horizontal, 16)

			if self.showingLog || self.showingSettings
			{
				VStack() {
					Divider()
					if self.showingLog
					{
						LogView()
					}
					else if self.showingSettings
					{
						SettingsView(musicCon: self.$musicCon)
					}
				}
				.padding(.top, -8)
			}
		}
	}
}




