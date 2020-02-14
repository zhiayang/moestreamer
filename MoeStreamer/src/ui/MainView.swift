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

	@State var showingSettings: Bool = false
	@State var showingLog: Bool = false
	@State var spinAngle: Angle = .zero

	@ObservedObject private var model: MainModel

	var iconColour: Color {
		return self.colourScheme == .light ? .black : .white
	}


	init(model: MainModel)
	{
		self.model = model
	}

    var body: some View {
		VStack() {
			ZStack(alignment: .topTrailing) {
				GeometryReader() { (geom) in
					HStack() {
						self.model.albumArt?
							.frame(width: 96, height: 96, alignment: .leading)
							.cornerRadius(5)
							.shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.65), radius: 5, x: 1, y: 1.5)
							.padding(.trailing, 8)

						VStack(alignment: .leading) {

							VStack(alignment: .leading) {
								Text(self.model.songTitle)
									.multilineTextAlignment(.leading)
									.padding(.bottom, 4)
									.animation(nil)

								Text(self.model.songArtist)
									.font(.system(size: 11))
									.multilineTextAlignment(.leading)
									.animation(nil)
							}
							.frame(height: 70)
							.padding(.top, 8)
							.padding(.trailing, 8)
							.opacity(self.model.textOpacity)
							// .border(Color.yellow)

							HStack(spacing: 2) {
								// play/pause button
								Button(action: {
									self.model.isPlaying.toggle()
									self.model.poke()
								}) {
									Image(nsImage: self.model.isPlaying ? #imageLiteral(resourceName: "Pause") : #imageLiteral(resourceName: "Play"))
										.resizable()
										.scaleEffect(1.75) // the icons for these are slightly different.
										.frame(width: 24, height: 24)
										.foregroundColor(self.iconColour)
								}
								.buttonStyle(PlainButtonStyle())
								.padding(.leading, -4)

								// favourite/unfavourite button
								if self.model.controller().getCapabilities().contains(.favourite) || true
								{
									Button(action: {
										self.model.controller().toggleFavourite()
									}) {
										ZStack() {
											// the filling: opacity will change depending on the state.
											Image(nsImage: #imageLiteral(resourceName: "Favourited"))
												.resizable()
												.scaleEffect(0.80)
												.opacity(self.model.favOpacity)
												.frame(width: 24, height: 24)
												.foregroundColor(self.iconColour)
												.zIndex(0)

											// the outside border: this one is always shown.
											Image(nsImage: #imageLiteral(resourceName: "FavouritedHollow"))
												.resizable()
												.scaleEffect(0.85)
												.frame(width: 24, height: 24)
												.foregroundColor(self.iconColour)
												.zIndex(1)
										}
									}
									.buttonStyle(PlainButtonStyle())
								}


								// mute/unmute button
								Button(action: {
//									let song: Song
//									if self.model.isMuted
//									{
//										song = Song(id: 100, title: "lmao what even",
//													album: ("kekw", #imageLiteral(resourceName: "zz_NoCoverArt")),
//													artists: [ "this is some artist" ],
//													isFavourite: .Yes)
//									}
//									else
//									{
//										song = Song(id: 101, title: "not playing",
//													album: (nil, nil),
//													artists: [ "omomomo" ],
//													isFavourite: .No)
//									}
//
//									self.model.onSongChange(song: song)

									self.model.isMuted.toggle()
									self.model.poke()
								}) {
									Image(nsImage: self.model.isMuted ? #imageLiteral(resourceName: "Mute") : #imageLiteral(resourceName: "VolUp"))
										.resizable()
										.frame(width: 24, height: 24)
										.foregroundColor(self.iconColour)
	//									.border(Color.green)
								}
								.buttonStyle(PlainButtonStyle())

								VolumeSlider(value: Binding(get: { self.model.volume },
															set: { self.model.volume = $0 })
								).padding(.leading, 4)

							}
							.padding(.bottom, 16) //.border(Color.green)
						}
					}.padding(.top, 0)
				}

				VStack(alignment: .trailing, spacing: 4) {
					Button(action: {
						self.model.controller().stop()
						NSApplication.shared.terminate(self)
					}) {
						Image(nsImage: #imageLiteral(resourceName: "Close"))
							.resizable()
							.frame(width: 16, height: 16)
							.foregroundColor(self.iconColour)
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
							.foregroundColor(self.iconColour)
					}
					.buttonStyle(PlainButtonStyle())

					Button(action: {
						self.showingLog.toggle()
						self.showingSettings = false
					}) {
						Image(nsImage: #imageLiteral(resourceName: "Log"))
							.resizable()
							.frame(width: 16, height: 16)
							.foregroundColor(self.iconColour)
					}
					.buttonStyle(PlainButtonStyle())

					Spacer()

					HStack(spacing: 2) {
						Spacer()

						if !self.model.status.isEmpty
						{
							Text(self.model.status)
								.font(Font.system(size: 10))
								.lineLimit(1)
								.transition(.opacity)
								.padding(.trailing, 4)
								.frame(maxWidth: 200, alignment: .trailing)
						}

						if self.model.spinning > 0
						{
							ActivityIndicator()
								.frame(width: 16, height: 16)
						}

						Button(action: {
							withAnimation(.spring(blendDuration: 3.5)) {
								self.spinAngle += .radians(2 * .pi)
							}

							self.model.controller().refresh()
							self.model.poke()
						}) {
							Image(nsImage: #imageLiteral(resourceName: "Refresh"))
								.resizable()
								.frame(width: 16, height: 16)
								.foregroundColor(self.iconColour)
								.rotationEffect(self.spinAngle)
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
					DispatchQueue.main.async {
						self.model.controller().refresh()
					}
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


