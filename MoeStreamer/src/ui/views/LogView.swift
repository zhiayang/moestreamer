// LogView.swift
// Copyright (c) 2020, zhiayang
// Licensed under the Apache License Version 2.0.

import Cocoa
import SwiftUI
import Foundation

struct LogView : View
{
	@ObservedObject var logger = Logger.instance

	var body: some View {
		VStack(alignment: .leading) {
			Spacer()

			HStack() {
				Text("event log")

				Spacer()

				Button(action: {
					withAnimation {
						self.logger.lines = [ ]
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
		.padding(.horizontal, 8)
		.padding(.bottom, 16)
		.frame(height: 190)
	}
}
