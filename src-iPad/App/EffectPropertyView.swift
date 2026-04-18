import SwiftUI

// Renders a single effect property as a SwiftUI control, based on its
// PropertyMetadata. Reads and writes through SequencerViewModel so changes
// propagate to the underlying Effect via XLSequenceDocument.
struct EffectPropertyView: View {
    @Environment(SequencerViewModel.self) var viewModel
    let property: PropertyMetadata
    let metadataPrefix: String      // "E_", "B_", "C_", "T_"

    private var settingKey: String { property.settingKey(prefix: metadataPrefix) }
    private var defaultValueString: String { property.defaultAsString() }

    /// Current raw value (string) from the underlying effect, falling back to
    /// the metadata default if not set. Empty selection → default.
    private var rawValue: String {
        viewModel.settingValue(forKey: settingKey, defaultValue: defaultValueString)
    }

    /// For properties flagged `suppressIfDefault: true` in the JSON metadata,
    /// pass the default through to the setter so it removes the key instead
    /// of persisting a redundant default. Nil → always write.
    private var suppressDefault: String? {
        (property.suppressIfDefault == true) ? defaultValueString : nil
    }

    private func writeValue(_ value: String) {
        viewModel.setSettingValue(value,
                                   forKey: settingKey,
                                   suppressIfDefault: suppressDefault)
    }

    var body: some View {
        switch property.controlType {
        case "slider":
            sliderView
        case "checkbox", "togglebutton":
            checkboxView
        case "choice", "combobox":
            choiceView
        case "spin":
            spinView
        case "text":
            textView
        case "filepicker":
            FilepickerPropertyView(property: property,
                                    currentPath: rawValue,
                                    onChoose: { writeValue($0) },
                                    onClear: { writeValue("") })
        case "fontpicker":
            FontpickerPropertyView(property: property,
                                    currentDesc: rawValue,
                                    onChange: { writeValue($0) })
        case "custom":
            customView
        default:
            unsupportedPlaceholder
        }
    }

    // MARK: - Custom property dispatcher

    // Route known custom property ids to their bespoke implementations.
    // Unknown custom rows show a neutral placeholder. C-6 fills this out
    // effect-by-effect in priority order.
    @ViewBuilder
    private var customView: some View {
        switch property.id {
        case "PaletteHeaderRow":
            ColorPaletteView()
        case "Pictures_FilenameBlock":
            EffectFilenameBlockView(label: "Image",
                                     settingKey: "E_TEXTCTRL_Pictures_Filename",
                                     fileFilter: "Images (*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.webp)|*.png;*.jpg;*.jpeg;*.gif;*.bmp;*.webp")
        case "Video_FilenameBlock":
            EffectFilenameBlockView(label: "Video",
                                     settingKey: "E_FILEPICKERCTRL_Video_Filename",
                                     fileFilter: "Videos (*.mp4;*.mov;*.m4v;*.avi;*.webm;*.mkv)|*.mp4;*.mov;*.m4v;*.avi;*.webm;*.mkv")
        case "Shader_FilenameBlock":
            EffectFilenameBlockView(label: "Shader",
                                     settingKey: "E_0FILEPICKERCTRL_IFS",
                                     fileFilter: "Shader (*.fs)|*.fs")
        case "Pictures_TransparentBlackRow":
            TransparentBlackRowView(effectKeyStem: "Pictures")
        case "Video_TransparentBlackRow":
            TransparentBlackRowView(effectKeyStem: "Video")
        case "Faces_TransparentBlackRow":
            TransparentBlackRowView(effectKeyStem: "Faces")
        case "Text_File_Row":
            EffectFilenameBlockView(label: "From File",
                                     settingKey: "E_FILEPICKERCTRL_Text_File",
                                     fileFilter: "Text (*.txt)|*.txt")
        case "Morph_Swap":
            MorphSwapRowView()
        default:
            customPlaceholder
        }
    }

    // MARK: - Slider

    private var sliderView: some View {
        let divisor = property.effectiveDivisor
        let minVal = property.min ?? 0
        let maxVal = property.max ?? 100

        // Derive live values from the observed rawValue on every body eval,
        // so the displayed text updates as the user slides.
        let storedInt = Int(rawValue) ?? 0
        let displayValue = Double(storedInt) / Double(divisor)

        let binding = Binding<Double>(
            get: { Double(storedInt) },
            set: { newVal in
                writeValue(String(Int(newVal)))
            }
        )

        // An active value curve replaces this slider's runtime value. Dim
        // the slider while one is active — the user can still scrub to
        // pre-set a fallback, but it won't apply until they toggle the
        // curve off in the VC editor.
        let vcKey = property.valueCurveKey(prefix: metadataPrefix)
        let vcActive = property.valueCurve == true
            && viewModel.settingValue(forKey: vcKey, defaultValue: "")
                .hasPrefix("Active=TRUE")

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(property.label)
                    .font(.caption)
                Spacer()
                Text(divisor > 1
                     ? String(format: "%.\(divisorDecimals(divisor))f", displayValue)
                     : "\(storedInt)")
                    .monospacedDigit()
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if property.valueCurve == true {
                    ValueCurveButton(property: property, prefix: metadataPrefix)
                }
            }
            Slider(value: binding, in: minVal...maxVal, step: 1)
                .opacity(vcActive ? 0.4 : 1.0)
                .disabled(vcActive)
        }
        .padding(.vertical, 2)
    }

    private func divisorDecimals(_ divisor: Int) -> Int {
        switch divisor {
        case 10: return 1
        case 100: return 2
        case 1000: return 3
        default: return 2
        }
    }

    // MARK: - Checkbox

    private var checkboxView: some View {
        let binding = Binding<Bool>(
            get: { rawValue == "1" || rawValue.lowercased() == "true" },
            set: { newVal in
                writeValue(newVal ? "1" : "0")
            }
        )
        let label = property.checkboxLabel ?? property.label
        return Toggle(isOn: binding) {
            Text(label.isEmpty ? property.label : label)
                .font(.caption)
        }
        .toggleStyle(.switch)
        .padding(.vertical, 2)
    }

    // MARK: - Choice / Combobox

    /// Resolves the option list for this choice. `dynamicOptions` takes
    /// precedence over the metadata's static `options` array — matches
    /// desktop's JsonEffectPanel (settings re-populated per selection
    /// change). If the dynamic source returns empty the list degrades to
    /// just the current value so the menu isn't blank.
    private var choiceOptions: [String] {
        if let source = property.dynamicOptions, !source.isEmpty {
            let dyn = viewModel.dynamicOptions(source: source,
                                                propertyId: property.id)
            if !dyn.isEmpty { return dyn }
            // Keep the current value selectable even when the source is
            // empty (e.g. a model with no states yet).
            let v = rawValue.isEmpty ? defaultValueString : rawValue
            return v.isEmpty ? [] : [v]
        }
        return property.options ?? []
    }

    private var choiceView: some View {
        let options = choiceOptions
        let binding = Binding<String>(
            get: { rawValue.isEmpty ? defaultValueString : rawValue },
            set: { writeValue($0) }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Text(property.label)
                .font(.caption)
            Picker(property.label, selection: binding) {
                ForEach(options, id: \.self) { opt in
                    Text(opt).tag(opt)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Spin (Stepper)

    private var spinView: some View {
        let minVal = Int(property.min ?? 0)
        let maxVal = Int(property.max ?? 100)
        let binding = Binding<Int>(
            get: { Int(rawValue) ?? Int(defaultValueString) ?? 0 },
            set: { writeValue(String($0)) }
        )
        return HStack {
            Text(property.label)
                .font(.caption)
            Spacer()
            Stepper(value: binding, in: minVal...maxVal) {
                Text("\(binding.wrappedValue)")
                    .monospacedDigit()
                    .font(.caption2)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Text

    private var textView: some View {
        let binding = Binding<String>(
            get: { rawValue },
            set: { writeValue($0) }
        )
        return VStack(alignment: .leading, spacing: 2) {
            Text(property.label)
                .font(.caption)
            TextField("", text: binding)
                .textFieldStyle(.roundedBorder)
                .font(.caption2)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Custom / Unsupported

    private var customPlaceholder: some View {
        HStack {
            Text(property.label.isEmpty ? property.id : property.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("(custom)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var unsupportedPlaceholder: some View {
        HStack {
            Text(property.label.isEmpty ? property.id : property.label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("(\(property.controlType))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}
