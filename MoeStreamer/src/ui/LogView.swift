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

	@ObservedObject var maxLogLines = SavedSettingModel<Int>(.logLinesRetain(), disableLogging: true, willset: {
		return (20 ... 1000).contains($0)
	})

	@State var textOpacity: Double = 1.0
	@State var scrollPos: CGPoint? = nil

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
				Text("line retention: ")

				Stepper(value: self.$maxLogLines.value, in: 20 ... 1000, step: 5) {
					TextField("", value: self.$maxLogLines.value, formatter: IntegerNumberFormatter())
						.frame(width: 40)
				}

				Spacer()

				Button(action: {
					withAnimation(.easeOut(duration: 0.15)) {
						self.textOpacity = 0

						DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
							self.logger.clear()
							self.textOpacity = 1
						}
					}
				}) {
					Text("clear")
				}
				.disabled(self.logger.getLines().isEmpty)
			}

			VStack() {
				GeometryReader { (geometry) in
					ScrollView(.vertical, scrollTo: self.$scrollPos) {
						if self.logger.getLines().isEmpty
						{
							EmptyView().frame(height: 40)
						}
						else
						{
							ForEach(self.logger.getLines(), id: \.self) { line in
								HStack() {
									Text(line.string())
										.font(.custom("Menlo", size: 10))
										.multilineTextAlignment(.leading)
										.frame(width: geometry.size.width, alignment: .leading)
										.foregroundColor(line.isError() ? .red : nil)
										.opacity(self.textOpacity)

									Spacer()
								}
								.padding(.leading, 4)
								.padding(.vertical, 2)
								.onAppear() {
									self.scrollPos = CGPoint(x: 0, y: 100000)
								}
							}

							if self.logger.getMsgRepeatCount() > 1
							{
								HStack() {
									Text("last message repeated \(self.logger.getMsgRepeatCount()) times")
										.font(.custom("Menlo", size: 10))
										.multilineTextAlignment(.leading)
										.foregroundColor(nil)
										.frame(alignment: .leading)
										.opacity(self.textOpacity)

									Spacer()
								}
								.padding(.leading, 4)
								.padding(.vertical, 2)
								.onAppear() {
									self.scrollPos = CGPoint(x: 0, y: 100000)
								}
							}
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
