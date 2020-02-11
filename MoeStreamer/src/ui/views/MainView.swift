// MainView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import SwiftUI
import Combine
import Foundation

private class Model : ObservableObject
{
	@Published var musicCon: ServiceController

	let objectWillChange = PassthroughSubject<Void, Never>()
	var isPlaying: Bool = false {
		didSet {
			if isPlaying
			{
				self.musicCon.start()
				self.musicCon.audioController().play()
			}
			else
			{
				self.musicCon.audioController().pause()
				self.musicCon.pause()
			}
			self.objectWillChange.send()
		}
	}

	var isMuted: Bool {
		get { self.musicCon.audioController().isMuted() }
		set {
			if newValue
			{
				self.musicCon.audioController().mute()
			}
			else
			{
				self.musicCon.audioController().unmute()
			}
			self.objectWillChange.send()
		}
	}

	var volume: Int {
		get { self.musicCon.audioController().getVolume() }
		set {
			self.musicCon.audioController().setVolume(volume: newValue)
			self.objectWillChange.send()
		}
	}

	func controller() -> ServiceController
	{
		return self.musicCon
	}

	init(controller: ServiceController)
	{
		self.musicCon = controller
	}
}

struct MainView : View
{
	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	@State var showingSettings: Bool = false
	@State var showingLog: Bool = false

	@ObservedObject	var wrapper: ViewWrapper
	@ObservedObject private var model: Model

	init(controller: ServiceController, viewWrapper: ViewWrapper)
	{
		self._wrapper = ObservedObject(wrappedValue: viewWrapper)

		self.model = Model(controller: controller)
	}

    var body: some View {
		VStack() {
			ZStack(alignment: .topTrailing) {
				HStack() {
					Image(nsImage: self.model.controller().getCurrentSong()?.album.1 ?? #imageLiteral(resourceName: "NoCoverArt"))
						.resizable()
						.shadow(radius: 5)
						.frame(width: 96, height: 96, alignment: .leading)
						.padding(.trailing, 8)
						.offset(y: -3)

					VStack(alignment: .leading) {

						VStack(alignment: .leading) {
							Text(self.model.controller().getCurrentSong()?.title ?? "not playing")
								.multilineTextAlignment(.leading)
								.padding(.bottom, 4)

							Text(self.model.controller().getCurrentSong()?.artists.joined(separator: ", ") ?? "—")
								.multilineTextAlignment(.leading)
						}.frame(height: 60)

						HStack(spacing: 2) {
							// play/pause button
							Button(action: {
								self.model.isPlaying.toggle()
								self.wrapper.poke()
							}) {
								Image(nsImage: self.model.isPlaying ? #imageLiteral(resourceName: "Pause") : #imageLiteral(resourceName: "Play"))
									.resizable()
									.frame(width: 24, height: 24)
									.foregroundColor(colourScheme == .light ? .black : .white)
							}
							.buttonStyle(PlainButtonStyle())

							// favourite/unfavourite button
							if self.model.controller().getCapabilities().contains(.favourite)
							{
								Button(action: {
									self.model.controller().toggleFavourite()
								}) {
									Image(nsImage: (self.model.controller().getCurrentSong()?.isFavourite ?? .No).icon())
										.resizable()
										.frame(width: 24, height: 24)
										.foregroundColor(colourScheme == .light ? .black : .white)
								}
								.buttonStyle(PlainButtonStyle())
							}

							// mute/unmute button
							Button(action: {
								self.model.isMuted.toggle()
								self.wrapper.poke()
							}) {
								Image(nsImage: self.model.isMuted ? #imageLiteral(resourceName: "Mute") : #imageLiteral(resourceName: "VolUp"))
									.resizable()
									.frame(width: 24, height: 24)
									.foregroundColor(colourScheme == .light ? .black : .white)
							}
							.buttonStyle(PlainButtonStyle())

							VolumeSlider(value: Binding(get: { self.model.volume },
														set: { self.model.volume = $0 })).padding(.leading, 4)

						}
						.padding(.bottom, 8)
					}
				}.padding(.top, 16)

				VStack(alignment: .trailing, spacing: 4) {
					Button(action: {
						self.model.controller().stop()
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
							self.model.controller().refresh()
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
			.onAppear {
				if let x: Bool = Settings.get(.shouldAutoRefresh()), x {
					self.model.controller().refresh()
				}
			}

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
						SettingsView(musicCon: Binding.constant(self.model.controller()))
					}
				}
				.padding(.top, -8)
			}
		}
	}
}




