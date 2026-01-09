//
//  RecipeDetailView.swift
//  QuillStack
//
//  Created on 2025-12-31.
//

import SwiftUI
import CoreData

struct RecipeDetailView: View, NoteDetailViewProtocol {
    @ObservedObject var note: Note
    @State private var recipe: ParsedRecipe = ParsedRecipe()
    @State private var checkedIngredients: Set<UUID> = []
    @State private var servingsMultiplier: Double = 1.0
    @State private var showingExportSheet: Bool = false
    @State private var showingShareSheet: Bool = false
    @State private var showingTypePicker = false
    @Bindable private var settings = SettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.creamLight.ignoresSafeArea()

            VStack(spacing: 0) {
                slimHeader

                ScrollView {
                    VStack(spacing: 20) {
                        recipeMetaCard
                        ingredientsCard
                        stepsCard

                        // Related notes section (QUI-161)
                        if note.linkCount > 0 {
                            RelatedNotesSection(note: note) { selectedNote in
                                // TODO: Navigate to selected note
                                print("Selected related note: \(selectedNote.id)")
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 80)
                }
                .background(
                    LinearGradient(
                        colors: [Color.paperBeige.opacity(0.98), Color.paperTan.opacity(0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                bottomBar
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            parseRecipe()
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportIngredientsSheet(ingredients: scaledIngredients, recipeTitle: recipe.title)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingTypePicker) {
            NoteTypePickerSheet(note: note)
        }
    }

    // MARK: - Header

    private var slimHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.forestLight)
                }

                Text(recipe.title.isEmpty ? "Recipe" : recipe.title)
                    .font(.serifBody(17, weight: .semibold))
                    .foregroundColor(.forestLight)
                    .lineLimit(1)

                Spacer()

                // Classification badge (only for automatic classifications)
                if note.classification.method.isAutomatic {
                    ClassificationBadge(classification: note.classification)
                }

                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 10, weight: .bold))
                    Text("RECIPE")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [Color.badgeRecipe, Color.badgeRecipe.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(4)
                .shadow(color: Color.badgeRecipe.opacity(0.3), radius: 2, x: 0, y: 1)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)

            HStack(spacing: 12) {
                Text(note.createdAt.shortFormat)
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))

                if !recipe.prepTime.isEmpty || !recipe.cookTime.isEmpty {
                    Text("•")
                        .foregroundColor(.textLight.opacity(0.5))

                    if !recipe.prepTime.isEmpty {
                        Label(recipe.prepTime, systemImage: "clock")
                            .font(.serifCaption(12, weight: .regular))
                            .foregroundColor(.textLight.opacity(0.8))
                    }
                }

                Spacer()

                Text("\(checkedIngredients.count)/\(recipe.ingredients.count) gathered")
                    .font(.serifCaption(12, weight: .regular))
                    .foregroundColor(.textLight.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(
            LinearGradient(
                colors: [Color.forestMedium, Color.forestDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    // MARK: - Recipe Meta Card

    private var recipeMetaCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if !recipe.servings.isEmpty {
                    metaItem(icon: "person.2", label: "Serves", value: scaledServings)
                }
                if !recipe.prepTime.isEmpty {
                    metaItem(icon: "clock", label: "Prep", value: recipe.prepTime)
                }
                if !recipe.cookTime.isEmpty {
                    metaItem(icon: "flame", label: "Cook", value: recipe.cookTime)
                }
            }

            if !recipe.servings.isEmpty {
                VStack(spacing: 8) {
                    Text("Scale Recipe")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.textMedium)

                    HStack(spacing: 12) {
                        ForEach([0.5, 1.0, 2.0, 3.0], id: \.self) { multiplier in
                            Button(action: { servingsMultiplier = multiplier }) {
                                Text(multiplier == 1.0 ? "1x" : "\(multiplier, specifier: multiplier == 0.5 ? "%.1f" : "%.0f")x")
                                    .font(.serifCaption(13, weight: .semibold))
                                    .foregroundColor(servingsMultiplier == multiplier ? .white : .textDark)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        servingsMultiplier == multiplier
                                            ? Color.badgeRecipe
                                            : Color.white
                                    )
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func metaItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.badgeRecipe)
            Text(value)
                .font(.serifBody(14, weight: .semibold))
                .foregroundColor(.textDark)
            Text(label)
                .font(.serifCaption(11, weight: .regular))
                .foregroundColor(.textMedium)
        }
        .frame(maxWidth: .infinity)
    }

    private var scaledServings: String {
        guard let base = Int(recipe.servings.filter { $0.isNumber }) else {
            return recipe.servings
        }
        let scaled = Int(Double(base) * servingsMultiplier)
        return "\(scaled)"
    }

    // MARK: - Ingredients Card

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(.serifHeadline(18, weight: .semibold))
                    .foregroundColor(.textDark)

                Spacer()

                Button(action: { showingExportSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "cart")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Shopping List")
                            .font(.serifCaption(12, weight: .semibold))
                    }
                    .foregroundColor(.badgeRecipe)
                }
            }

            ForEach(scaledIngredients) { ingredient in
                IngredientRowView(
                    ingredient: ingredient,
                    isChecked: checkedIngredients.contains(ingredient.id),
                    onToggle: {
                        if checkedIngredients.contains(ingredient.id) {
                            checkedIngredients.remove(ingredient.id)
                        } else {
                            checkedIngredients.insert(ingredient.id)
                        }
                    }
                )
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var scaledIngredients: [ParsedIngredient] {
        recipe.ingredients.map { ingredient in
            var scaled = ingredient
            if let qty = ingredient.quantity, servingsMultiplier != 1.0 {
                let scaledQty = qty * servingsMultiplier
                scaled.displayQuantity = formatQuantity(scaledQty)
            }
            return scaled
        }
    }

    private func formatQuantity(_ value: Double) -> String {
        let whole = Int(value)
        let frac = value - Double(whole)

        // Define fraction thresholds with tolerance for floating point
        let fractionDisplay: [(range: ClosedRange<Double>, display: String)] = [
            (0.115...0.135, "⅛"),   // ~0.125
            (0.240...0.260, "¼"),   // 0.25
            (0.320...0.345, "⅓"),   // ~0.33
            (0.365...0.385, "⅜"),   // 0.375
            (0.490...0.510, "½"),   // 0.5
            (0.615...0.635, "⅝"),   // 0.625
            (0.660...0.680, "⅔"),   // ~0.67
            (0.740...0.760, "¾"),   // 0.75
            (0.865...0.885, "⅞"),   // 0.875
        ]

        // Whole number (no fractional part)
        if frac < 0.05 {
            return whole == 0 ? "0" : "\(whole)"
        }

        // Check if fractional part matches a known fraction
        for (range, display) in fractionDisplay {
            if range.contains(frac) {
                return whole > 0 ? "\(whole)\(display)" : display
            }
        }

        // Fallback to decimal for non-standard values
        return String(format: "%.1f", value)
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.serifHeadline(18, weight: .semibold))
                .foregroundColor(.textDark)

            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.serifBody(14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.badgeRecipe)
                        .clipShape(Circle())

                    Text(step)
                        .font(.serifBody(15, weight: .regular))
                        .foregroundColor(.textDark)
                        .lineSpacing(4)
                }
                .padding(.vertical, 8)

                if index < recipe.steps.count - 1 {
                    Divider()
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 20) {
            // Change Type button
            Button(action: { showingTypePicker = true }) {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .accessibilityLabel("Change note type")

            Button(action: shareRecipe) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Button(action: copyContent) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.textDark)
            }

            Spacer()

            Button(action: { showingExportSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Export to Shopping")
                        .font(.serifBody(14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: [Color.badgeRecipe, Color.badgeRecipe.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - NoteDetailViewProtocol

    func saveChanges() {
        // RecipeDetailView is read-only from parsed content
    }

    // MARK: - Parsing

    private func parseRecipe() {
        let classifier = TextClassifier()
        let content: String
        if let extracted = classifier.extractTriggerTag(from: note.content) {
            content = extracted.cleanedContent
        } else {
            content = note.content
        }

        let lines = content.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        var parsed = ParsedRecipe()
        var currentSection: RecipeSection = .title
        var stepBuffer: [String] = []
        var ingredientBuffer: [ParsedIngredient] = []

        for line in lines {
            guard !line.isEmpty else { continue }

            let lower = line.lowercased()

            // Detect section headers
            if lower.contains("ingredient") {
                currentSection = .ingredients
                continue
            } else if lower.contains("instruction") || lower.contains("direction") || lower.contains("step") || lower.contains("method") {
                currentSection = .steps
                continue
            }

            // Parse metadata from first lines
            if parsed.title.isEmpty && currentSection == .title {
                parsed.title = line
                currentSection = .meta
                continue
            }

            // Parse metadata
            if currentSection == .meta || currentSection == .title {
                if lower.contains("serve") || lower.contains("yield") {
                    if let servings = extractNumber(from: line) {
                        parsed.servings = servings
                    }
                    continue
                }
                if lower.contains("prep") {
                    parsed.prepTime = extractTime(from: line) ?? line
                    continue
                }
                if lower.contains("cook") || lower.contains("bake") {
                    parsed.cookTime = extractTime(from: line) ?? line
                    continue
                }
            }

            // Detect ingredients (lines with quantities/measurements)
            if currentSection == .ingredients || looksLikeIngredient(line) {
                if currentSection != .steps {
                    currentSection = .ingredients
                    if let ingredient = parseIngredient(line) {
                        ingredientBuffer.append(ingredient)
                    }
                    continue
                }
            }

            // Detect steps (lines starting with numbers or verbs)
            if currentSection == .steps || looksLikeStep(line) {
                currentSection = .steps
                let cleanStep = cleanStepText(line)
                if !cleanStep.isEmpty {
                    stepBuffer.append(cleanStep)
                }
            }
        }

        parsed.ingredients = ingredientBuffer
        parsed.steps = stepBuffer
        recipe = parsed
    }

    private func looksLikeIngredient(_ line: String) -> Bool {
        let measurements = ["cup", "tbsp", "tsp", "tablespoon", "teaspoon", "oz", "lb", "pound", "ounce", "gram", "g", "kg", "ml", "liter"]
        let lower = line.lowercased()

        // Has a number at the start
        if line.first?.isNumber == true {
            // And contains a measurement word
            for m in measurements {
                if lower.contains(m) { return true }
            }
            // Or is short enough to be an ingredient
            if line.count < 60 { return true }
        }

        // Starts with fraction
        let fractions = ["½", "¼", "¾", "⅓", "⅔", "⅛", "⅜", "⅝", "⅞",
                         "1/2", "1/4", "3/4", "1/3", "2/3", "1/8", "3/8", "5/8", "7/8"]
        for f in fractions {
            if line.hasPrefix(f) { return true }
        }

        return false
    }

    private func looksLikeStep(_ line: String) -> Bool {
        let cookingVerbs = ["mix", "stir", "add", "combine", "pour", "bake", "cook", "heat", "preheat", "place", "spread", "fold", "whisk", "beat", "mash", "slice", "chop", "dice", "melt", "boil", "simmer", "fry", "sauté", "roast", "grill", "blend", "cream", "set", "let", "remove", "transfer", "serve"]
        let lower = line.lowercased()

        // Starts with a number (step number)
        if let first = line.first, first.isNumber {
            return true
        }

        // Starts with a cooking verb
        let firstWord = lower.components(separatedBy: .whitespaces).first ?? ""
        return cookingVerbs.contains(firstWord)
    }

    private func parseIngredient(_ line: String) -> ParsedIngredient? {
        var text = line.trimmingCharacters(in: .whitespaces)

        // Remove bullet points
        let bullets = ["•", "-", "*", "·"]
        for bullet in bullets {
            if text.hasPrefix(bullet) {
                text = String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard !text.isEmpty else { return nil }

        // Try to extract quantity
        var quantity: Double?
        var displayQty: String = ""
        var remainder = text

        // Check for fraction at start
        let fractionMap: [(String, Double)] = [
            ("½", 0.5), ("¼", 0.25), ("¾", 0.75), ("⅓", 0.33), ("⅔", 0.67),
            ("⅛", 0.125), ("⅜", 0.375), ("⅝", 0.625), ("⅞", 0.875),
            ("1/2", 0.5), ("1/4", 0.25), ("3/4", 0.75), ("1/3", 0.33), ("2/3", 0.67),
            ("1/8", 0.125), ("3/8", 0.375), ("5/8", 0.625), ("7/8", 0.875)
        ]

        for (frac, val) in fractionMap {
            if remainder.hasPrefix(frac) {
                quantity = val
                displayQty = frac
                remainder = String(remainder.dropFirst(frac.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Check for whole number at start
        if quantity == nil {
            let pattern = "^([0-9]+\\.?[0-9]*)\\s*"
            if let match = remainder.range(of: pattern, options: .regularExpression) {
                let numStr = String(remainder[match]).trimmingCharacters(in: .whitespaces)
                if let num = Double(numStr) {
                    quantity = num
                    displayQty = numStr
                    remainder = String(remainder[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // Check for whole number + fraction (e.g., "1 1/2")
        if let q = quantity {
            for (frac, val) in fractionMap {
                if remainder.hasPrefix(frac) {
                    quantity = q + val
                    displayQty = "\(Int(q)) \(frac)"
                    remainder = String(remainder.dropFirst(frac.count)).trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        return ParsedIngredient(
            originalText: line,
            quantity: quantity,
            displayQuantity: displayQty.isEmpty ? nil : displayQty,
            name: remainder
        )
    }

    private func extractNumber(from text: String) -> String? {
        let pattern = "([0-9]+)"
        if let match = text.range(of: pattern, options: .regularExpression) {
            return String(text[match])
        }
        return nil
    }

    private func extractTime(from text: String) -> String? {
        let patterns = [
            "([0-9]+\\s*(?:hour|hr|min|minute)[s]?)",
            "([0-9]+\\s*-\\s*[0-9]+\\s*(?:hour|hr|min|minute)[s]?)"
        ]

        let lower = text.lowercased()
        for pattern in patterns {
            if let match = lower.range(of: pattern, options: .regularExpression) {
                return String(text[match])
            }
        }
        return nil
    }

    private func cleanStepText(_ text: String) -> String {
        var cleaned = text

        // Remove leading numbers and punctuation
        let pattern = "^[0-9]+[.)\\s]*"
        if let match = cleaned.range(of: pattern, options: .regularExpression) {
            cleaned = String(cleaned[match.upperBound...])
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Actions

    private func shareRecipe() {
        let text = formatRecipeForSharing()
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func copyContent() {
        UIPasteboard.general.string = formatRecipeForSharing()
    }

    private func formatRecipeForSharing() -> String {
        var text = "🍳 \(recipe.title)\n\n"

        if !recipe.servings.isEmpty || !recipe.prepTime.isEmpty || !recipe.cookTime.isEmpty {
            if !recipe.servings.isEmpty { text += "Serves: \(scaledServings)\n" }
            if !recipe.prepTime.isEmpty { text += "Prep: \(recipe.prepTime)\n" }
            if !recipe.cookTime.isEmpty { text += "Cook: \(recipe.cookTime)\n" }
            text += "\n"
        }

        text += "📝 Ingredients:\n"
        for ingredient in scaledIngredients {
            if let qty = ingredient.displayQuantity {
                text += "• \(qty) \(ingredient.name)\n"
            } else {
                text += "• \(ingredient.name)\n"
            }
        }

        text += "\n👨‍🍳 Instructions:\n"
        for (index, step) in recipe.steps.enumerated() {
            text += "\(index + 1). \(step)\n"
        }

        return text
    }
}

// MARK: - Models

enum RecipeSection {
    case title, meta, ingredients, steps
}

struct ParsedRecipe {
    var title: String = ""
    var servings: String = ""
    var prepTime: String = ""
    var cookTime: String = ""
    var ingredients: [ParsedIngredient] = []
    var steps: [String] = []
}

struct ParsedIngredient: Identifiable {
    let id = UUID()
    var originalText: String
    var quantity: Double?
    var displayQuantity: String?
    var name: String
}

// MARK: - Ingredient Row View

struct IngredientRowView: View {
    let ingredient: ParsedIngredient
    let isChecked: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isChecked ? .badgeRecipe : .textMedium.opacity(0.4))

                if let qty = ingredient.displayQuantity {
                    Text(qty)
                        .font(.serifBody(15, weight: .semibold))
                        .foregroundColor(isChecked ? .textMedium : .textDark)
                }

                Text(ingredient.name)
                    .font(.serifBody(15, weight: .regular))
                    .foregroundColor(isChecked ? .textMedium : .textDark)
                    .strikethrough(isChecked, color: .textMedium.opacity(0.5))

                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Export Ingredients Sheet

struct ExportIngredientsSheet: View {
    let ingredients: [ParsedIngredient]
    let recipeTitle: String
    @Environment(\.dismiss) private var dismiss

    @State private var authorizationStatus: RemindersService.AuthorizationStatus = .notDetermined
    @State private var selectedList: EKCalendar?
    @State private var availableLists: [EKCalendar] = []
    @State private var selectedIngredients: Set<UUID> = []
    @State private var isExporting = false
    @State private var showResults = false
    @State private var exportResults: [ReminderExportResult] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                Group {
                    switch authorizationStatus {
                    case .notDetermined:
                        requestAccessView
                    case .denied, .restricted:
                        accessDeniedView
                    case .authorized:
                        if showResults {
                            resultsView
                        } else {
                            exportOptionsView
                        }
                    }
                }
            }
            .navigationTitle("Shopping List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.forestDark)
                }
            }
            .onAppear {
                checkAuthorization()
            }
        }
    }

    private var requestAccessView: some View {
        VStack(spacing: 24) {
            Image(systemName: "cart")
                .font(.system(size: 56))
                .foregroundColor(.forestDark)

            Text("Reminders Access Required")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("QuillStack needs access to your Reminders to create a shopping list.")
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: requestAccess) {
                Text("Grant Access")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.forestDark)
                    .cornerRadius(10)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accessDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle")
                .font(.system(size: 56))
                .foregroundColor(.orange)

            Text("Access Denied")
                .font(.serifHeadline(20, weight: .semibold))
                .foregroundColor(.textDark)

            Text("Please enable Reminders access in Settings to create shopping lists.")
                .font(.serifBody(15, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.forestDark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var exportOptionsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    listPickerSection
                    ingredientSelectionSection
                }
                .padding(20)
            }
            exportButton
        }
    }

    private var listPickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders List")
                .font(.serifCaption(13, weight: .semibold))
                .foregroundColor(.textMedium)

            Menu {
                ForEach(availableLists, id: \.calendarIdentifier) { list in
                    Button(action: { selectedList = list }) {
                        HStack {
                            Circle()
                                .fill(Color(cgColor: list.cgColor))
                                .frame(width: 12, height: 12)
                            Text(list.title)
                            if selectedList?.calendarIdentifier == list.calendarIdentifier {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    if let list = selectedList {
                        Circle()
                            .fill(Color(cgColor: list.cgColor))
                            .frame(width: 16, height: 16)
                        Text(list.title)
                            .font(.serifBody(16, weight: .medium))
                            .foregroundColor(.textDark)
                    } else {
                        Text("Select a list")
                            .font(.serifBody(16, weight: .medium))
                            .foregroundColor(.textMedium)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundColor(.textMedium)
                }
                .padding(14)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }

    private var ingredientSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients for \(recipeTitle)")
                    .font(.serifCaption(13, weight: .semibold))
                    .foregroundColor(.textMedium)
                    .lineLimit(1)

                Spacer()

                Button(action: toggleSelectAll) {
                    Text(selectedIngredients.count == ingredients.count ? "Deselect All" : "Select All")
                        .font(.serifCaption(12, weight: .medium))
                        .foregroundColor(.forestDark)
                }
            }

            VStack(spacing: 0) {
                ForEach(ingredients) { ingredient in
                    Button(action: { toggleIngredient(ingredient) }) {
                        HStack(spacing: 14) {
                            Image(systemName: selectedIngredients.contains(ingredient.id) ? "checkmark.square.fill" : "square")
                                .font(.system(size: 20))
                                .foregroundColor(selectedIngredients.contains(ingredient.id) ? .badgeRecipe : .textMedium)

                            if let qty = ingredient.displayQuantity {
                                Text("\(qty) \(ingredient.name)")
                                    .font(.serifBody(15, weight: .regular))
                                    .foregroundColor(.textDark)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            } else {
                                Text(ingredient.name)
                                    .font(.serifBody(15, weight: .regular))
                                    .foregroundColor(.textDark)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()
                        }
                        .padding(14)
                    }

                    if ingredient.id != ingredients.last?.id {
                        Divider()
                    }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private var exportButton: some View {
        VStack(spacing: 12) {
            Button(action: exportIngredients) {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "cart.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(isExporting ? "Exporting..." : "Add \(selectedIngredients.count) Item\(selectedIngredients.count == 1 ? "" : "s") to List")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: canExport ? [Color.badgeRecipe, Color.badgeRecipe.opacity(0.8)] : [Color.gray, Color.gray.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(!canExport || isExporting)
        }
        .padding(20)
        .background(Color.creamLight)
        .overlay(
            Rectangle()
                .fill(Color.forestDark.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }

    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    let successCount = exportResults.filter { $0.success }.count
                    let failCount = exportResults.filter { !$0.success }.count

                    VStack(spacing: 12) {
                        Image(systemName: failCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(failCount == 0 ? .green : .orange)

                        Text(failCount == 0 ? "Shopping List Created" : "Export Finished")
                            .font(.serifHeadline(20, weight: .semibold))
                            .foregroundColor(.textDark)

                        Text("\(successCount) item\(successCount == 1 ? "" : "s") added to your shopping list\(failCount > 0 ? ", \(failCount) failed" : "")")
                            .font(.serifBody(14, weight: .regular))
                            .foregroundColor(.textMedium)
                    }
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        ForEach(exportResults) { result in
                            HStack(spacing: 12) {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.success ? .green : .red)

                                Text(result.task)
                                    .font(.serifBody(14, weight: .regular))
                                    .foregroundColor(.textDark)
                                    .lineLimit(1)

                                Spacer()
                            }
                            .padding(12)

                            if result.id != exportResults.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .padding(20)
            }

            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.forestDark)
                    .cornerRadius(12)
            }
            .padding(20)
            .background(Color.creamLight)
        }
    }

    // MARK: - Helpers

    private var canExport: Bool {
        selectedList != nil && !selectedIngredients.isEmpty
    }

    private func checkAuthorization() {
        authorizationStatus = RemindersService.shared.authorizationStatus
        if authorizationStatus == .authorized {
            loadLists()
        }
    }

    private func requestAccess() {
        Task {
            let granted = await RemindersService.shared.requestAccess()
            await MainActor.run {
                authorizationStatus = granted ? .authorized : .denied
                if granted {
                    loadLists()
                }
            }
        }
    }

    private func loadLists() {
        availableLists = RemindersService.shared.getReminderLists()
        selectedList = RemindersService.shared.getDefaultReminderList()
        selectedIngredients = Set(ingredients.map { $0.id })
    }

    private func toggleIngredient(_ ingredient: ParsedIngredient) {
        if selectedIngredients.contains(ingredient.id) {
            selectedIngredients.remove(ingredient.id)
        } else {
            selectedIngredients.insert(ingredient.id)
        }
    }

    private func toggleSelectAll() {
        if selectedIngredients.count == ingredients.count {
            selectedIngredients.removeAll()
        } else {
            selectedIngredients = Set(ingredients.map { $0.id })
        }
    }

    private func exportIngredients() {
        guard let list = selectedList else { return }

        let itemsToExport = ingredients.filter { selectedIngredients.contains($0.id) }
        let tasks = itemsToExport.map { ingredient -> ParsedTask in
            let text: String
            if let qty = ingredient.displayQuantity {
                text = "\(qty) \(ingredient.name)"
            } else {
                text = ingredient.name
            }
            return ParsedTask(text: text, isCompleted: false)
        }

        isExporting = true

        Task {
            let results = try? await RemindersService.shared.exportTasks(tasks, toList: list)
            await MainActor.run {
                exportResults = results ?? []
                isExporting = false
                showResults = true
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

import EventKit

#Preview {
    RecipeDetailView(note: Note())
}
