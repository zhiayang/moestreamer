// LogView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

struct LogView : View
{
	@ObservedObject var logger = Logger.instance
	@ObservedObject var stats = Statistics.instance

	@State var textOpacity: Double = 1.0

	var body: some View {
		VStack(alignment: .leading) {
			Spacer()

			HStack() {
				Text("songs played: \(self.stats.songsPlayed)")

				Spacer()

				Button(action: {
					self.stats.reset()
				}) {
					Text("reset")
				}
			}

			HStack() {
				Text("event log")

				Spacer()

				Button(action: {
					withAnimation(.easeOut(duration: 0.15)) {
						self.textOpacity = 0

						DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
							self.logger.lines = [ ]
							self.textOpacity = 1
						}
					}
				}) {
					Text("clear")
				}
				.disabled(self.logger.lines.isEmpty)
			}

			VStack() {
				ScrollView() {
					if self.logger.lines.isEmpty
					{
						EmptyView().frame(height: 40)
					}
					else
					{
						ForEach(self.logger.lines, id: \.self) { line in
							HStack() {
								Text(line.string())
									.font(.custom("Menlo", size: 10))
									.multilineTextAlignment(.leading)
									.foregroundColor(line.isError() ? .red : nil)
									.frame(alignment: .leading)
									.opacity(self.textOpacity)

								Spacer()
							}
							.padding(.leading, 4)
							.padding(.vertical, 2)
						}

						if self.logger.msgRepeatCount > 1
						{
							HStack() {
								Text("last message repeated \(self.logger.msgRepeatCount) times")
									.font(.custom("Menlo", size: 10))
									.multilineTextAlignment(.leading)
									.foregroundColor(nil)
									.frame(alignment: .leading)
									.opacity(self.textOpacity)

								Spacer()
							}
							.padding(.leading, 4)
							.padding(.vertical, 2)
						}
					}
				}
				.padding(.top, 4)
			}
			.background(Color(red: 0.1, green: 0.1, blue: 0.1))
		}
		.padding(.horizontal, 12)
		.padding(.bottom, 16)
		.frame(height: 190)
	}
}
