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
	@State var searchField: CustomSearchField! = nil
	@State var scrollPos: CGPoint? = nil
	@State var searchState: SearchState = .None
	@State var searchResults: [Song] = []
	@State var resultWindowHeight: CGFloat = 0

	let defaultResultHeight: CGFloat = 10

	@Binding var musicCon: ServiceController

	@Environment(\.colorScheme)
	var colourScheme: ColorScheme

	var iconColour: Color {
		return self.colourScheme == .light ? .black : .white
	}


	init(musicCon: Binding<ServiceController>)
	{
		self._musicCon = musicCon
		self.resultWindowHeight = self.defaultResultHeight
	}

	private func performSearch(with name: String)
	{
		let setResultHeight = {
			let n = min(self.searchResults.count, 3)
			self.resultWindowHeight = defaultResultHeight + CGFloat(n * 70)
		}

		self.searchResults = []
		self.searchState = .InProgress
		self.musicCon.searchSongs(name: name, inProgress: {

			self.searchResults.append($0)
			DispatchQueue.main.async {
				setResultHeight()
			}

		}, onComplete: {
			DispatchQueue.main.async {
				setResultHeight()
				self.searchState = .Done
			}
		})
	}

	var body: some View {

		VStack(spacing: 5) {
			ZStack() {
				BetterTextField<CustomSearchField>(
					placeholder: "search", text: self.$searchString, field: self.$searchField,
					setupField: {
						$0.sendsWholeSearchString = true
						$0.sendsSearchStringImmediately = false

						($0.cell as! NSSearchFieldCell).sendsWholeSearchString = true
						($0.cell as! NSSearchFieldCell).sendsSearchStringImmediately = false
					},
					onFinishEditing: { (text, _) in
						self.performSearch(with: text)
					})
					.frame(width: 200, alignment: .center)
					.onAppear(perform: {
						self.searchState = .None
						DispatchQueue.main.async {
							self.searchField.becomeFirstResponder()
						}
					})
					.onDisappear(perform: {
						DispatchQueue.main.async {
							AppDelegate.shared.controller.becomeFirstResponder()
						}
					})

				if self.searchState == .InProgress
				{
					ActivityIndicator(size: .small)
						.frame(width: 20, height: 20)
						.padding(.leading, 240)
				}
			}
			.frame(maxWidth: .infinity)

			Spacer()

			VStack() {
				if self.searchResults.isEmpty
				{
					Text("no results")
				}
				else
				{
					List(self.searchResults, id: \.self, rowContent: { song in
						SongView(for: song, using: self.$musicCon)
							.padding(.all, 6)
							.background(Color(.sRGBLinear, white: self.colourScheme == .light ? 0.3 : 0.4,
											  opacity: 0.15))
							.cornerRadius(10)
							.padding([.leading, .trailing], 5)
					})
				}
			}
			.animation(.interactiveSpring())
			.frame(minHeight: self.resultWindowHeight, maxHeight: self.resultWindowHeight)

			Spacer()
		}
		.padding(.vertical, 5)
		.padding(.horizontal, 0)
	}
}




fileprivate struct SongView : View
{
	var song: Song

	@Binding var musicCon: ServiceController

	@Environment(\.colorScheme)
	var colourScheme: ColorScheme
	var iconColour: Color {
		return self.colourScheme == .light ? .black : .white
	}

	init(for song: Song, using musicCon: Binding<ServiceController>)
	{
		self._musicCon = musicCon
		self.song = song
	}

	var body: some View {
		HStack() {
			if let art = song.album.1
			{
				Image(nsImage: art)
					.resizable()
					.frame(width: 48, height: 48)
					.cornerRadius(3)
					.shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.65),
							radius: 5, x: 1, y: 1.5)
			}
			else
			{
				MainModel.getDefaultAlbumArt()
			}

			EmptyView()
				.padding(.trailing, 2)

			VStack(alignment: .leading, spacing: 1) {
				Button(action: {
					self.musicCon.enqueueSong(song, immediately: true)
				}) {
					Image(nsImage: #imageLiteral(resourceName: "zz_Play"))
						.resizable()
						.frame(width: 18, height: 18)
						.foregroundColor(self.iconColour)
						.tooltip("play the song now")
				}
				.buttonStyle(PlainButtonStyle())

				Button(action: {
					self.musicCon.enqueueSong(song, immediately: false)
				}) {
					Image(nsImage: #imageLiteral(resourceName: "PlayNext"))
						.resizable()
						.frame(width: 18, height: 18)
						.foregroundColor(self.iconColour)
						.padding(.leading, 4)
						.tooltip("play after the current song finishes")
				}
				.buttonStyle(PlainButtonStyle())

			}.padding(.trailing, 2)

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
		}
		.padding(.leading, 5)
		.frame(height: 50)
	}
}
