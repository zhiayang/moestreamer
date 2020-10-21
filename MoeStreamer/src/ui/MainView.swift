// MainView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import VLCKit
import SwiftUI
import Foundation

enum SubViewKind_
{
	case None
	case Settings
	case Search
	case Log
}

class SubViewKind : ObservableObject
{
	@Published var kind: SubViewKind_

	init(of: SubViewKind_)
	{
		self.kind = of
	}

	func toggle(into: SubViewKind_)
	{
		if self.kind == into { self.kind = .None }
		else                 { self.kind = into }
	}
}

struct MainView : View
{
	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	@ObservedObject var currentSubView: SubViewKind = SubViewKind(of: .None)
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
							.padding(.trailing, 16)
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


								// skip button
								if self.model.controller().getCapabilities().contains(.nextTrack)
								{
									Button(action: {
										self.model.controller().nextSong()
									}) {
										Image(nsImage: #imageLiteral(resourceName: "NextSong"))
											.resizable()
											.scaleEffect(1.35) // the icons for these are slightly different.
											.frame(width: 24, height: 24)
											.foregroundColor(self.iconColour)
									}
									.buttonStyle(PlainButtonStyle())
								}

								// favourite/unfavourite button
								if self.model.controller().getCapabilities().contains(.favourite)
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
								)
								.padding(.leading, 4)
								.padding(.trailing, 8)

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
						self.currentSubView.toggle(into: .Settings)
					}) {
						Image(nsImage: #imageLiteral(resourceName: "Settings"))
							.resizable()
							.frame(width: 16, height: 16)
							.foregroundColor(self.iconColour)
					}
					.buttonStyle(PlainButtonStyle())

					// if the backend doesn't support search (eg. listen.moe) then don't show the button, duh
					if self.model.controller().getCapabilities().contains(.searchTracks)
					{
						Button(action: {
							self.currentSubView.toggle(into: .Search)
						}) {
							Image(nsImage: #imageLiteral(resourceName: "Search"))
								.resizable()
								.frame(width: 16, height: 16)
								.foregroundColor(self.iconColour)
						}
						.buttonStyle(PlainButtonStyle())
					}

					Button(action: {
						self.currentSubView.toggle(into: .Log)
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

			if self.currentSubView.kind != .None
			{
				VStack() {
					Divider()

					let musicConBinding = Binding(get: { self.model.controller() },
												  set: { self.model.set(controller: $0) })

					switch self.currentSubView.kind
					{
						case .None:
							EmptyView()

						case .Log:
							LogView()

						case .Search:
							SearchView(musicCon: musicConBinding)

						case .Settings:
							SettingsView(musicCon: musicConBinding)
					}
				}.padding(.top, -8)
			}
		}
	}
}


