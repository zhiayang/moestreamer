// LogView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import SwiftUI
import Foundation

enum SearchState
{
	case None
	case InProgress
	case Done
}

struct SearchView : View
{
	@State var searchString: String = ""
	@State var searchField: NSSearchField! = nil
	@State var scrollPos: CGPoint? = nil
	@State var searchState: SearchState = .None
	@State var searchResults: [Song] = []

	@Binding var musicCon: ServiceController

	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	var iconColour: Color {
		return self.colourScheme == .light ? .black : .white
	}


	init(musicCon: Binding<ServiceController>)
	{
		self._musicCon = musicCon
	}

	private func performSearch(with name: String)
	{
		self.searchResults = []
		self.searchState = .InProgress
		self.musicCon.searchSongs(name: name, into: self.$searchResults, onComplete: {
			DispatchQueue.main.async {
				self.searchState = .Done
			}
		})
	}

	var body: some View {
		VStack(spacing: 5) {
			ZStack() {
				BetterTextField<NSSearchField>(
					placeholder: "search", text: self.$searchString, field: self.$searchField,
					setupField: {
						$0.sendsWholeSearchString = true
						$0.sendsSearchStringImmediately = false

						($0.cell as! NSSearchFieldCell).sendsWholeSearchString = true
						($0.cell as! NSSearchFieldCell).sendsSearchStringImmediately = false
					},
					onEnter: { (_, field: NSSearchField) in
						self.performSearch(with: field.stringValue)
					})
					.frame(width: 200)
					.onAppear(perform: {
						self.searchState = .None
						DispatchQueue.main.async {
							self.searchField.window?.makeFirstResponder(self.searchField)
						}
					}).frame(alignment: .center)

				if self.searchState == .InProgress
				{
					ActivityIndicator(size: .small)
						.frame(width: 20, height: 20)
						.padding(.leading, 240)
				}
			}
			.frame(maxWidth: .infinity)

			Spacer()

			if self.searchState == .Done && self.searchResults.isEmpty
			{
				Text("no results")
					.frame(height: 30)
			}
			else
			{
				SwiftUI.ScrollView(.vertical, showsIndicators: true) {
					VStack() {
						ForEach(self.searchResults) { song in
							HStack() {
								if let art = song.album.1 { Image(nsImage: art).resizable().scaledToFit() }
								else                      { MainModel.getDefaultAlbumArt() }

								VStack(alignment: .leading) {
									Text(song.title)
										.multilineTextAlignment(.leading)
										.padding(.bottom, 4)
										.animation(nil)

									Text(song.artists.joined(separator: ", "))
										.font(.system(size: 11))
										.multilineTextAlignment(.leading)
										.animation(nil)
								}

								Spacer()

								VStack(spacing: 1) {
									Button(action: {
										self.musicCon.setNextSong(song, immediately: true)
									}) {
										Image(nsImage: #imageLiteral(resourceName: "zz_Play"))
											.resizable()
											.frame(width: 18, height: 18)
											.foregroundColor(self.iconColour)
									}
									.buttonStyle(PlainButtonStyle())
									.tooltip("play the song now")

									Button(action: {
										self.musicCon.setNextSong(song, immediately: false)
									}) {
										Image(nsImage: #imageLiteral(resourceName: "PlayNext"))
											.resizable()
											.frame(width: 18, height: 18)
											.foregroundColor(self.iconColour)
											.padding(.leading, 4)
									}
									.buttonStyle(PlainButtonStyle())
									.tooltip("play after the current song finishes")
								}.padding(.trailing, 15)

							}.frame(height: 50)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
					}.frame(width: 320)
				}
				.frame(minHeight: self.searchResults.isEmpty ? 10 : 150, maxHeight: 400)
			}

			Spacer()
		}
		.padding(.vertical, 5)
		.padding(.horizontal, 0)
		.frame(maxHeight: .infinity)
	}
}
