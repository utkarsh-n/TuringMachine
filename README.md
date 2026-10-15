# The Turing Machine

A native iPhone computation instrument for iOS 27, built with SwiftUI, Liquid Glass, Core Motion, and Metal. Open `TuringMachine.xcodeproj` and run the `TuringMachine` scheme.

The machine executes a deterministic, single-tape Turing model exactly: its current state and read symbol select one transition; that transition writes one symbol, moves one cell left or right, and changes state atomically. There is no hidden arithmetic or preset-specific shortcut. The sparse tape extends to negative and positive coordinates; absent cells mean blank. Accept, reject, and an undefined transition remain distinct outcomes.

## Use the instrument

- Choose a program from the glass program selector.
- Tap **Step** to execute one atomic transition. **Back** restores the previous configuration, including erased symbols and terminal states.
- Turn the read-head dial to set 1–12 transitions per second, then press **Run**. The amber tempo value shows the requested rate.
- Tap a tape cell to write any symbol in Γ or place the head there. Swipe the tape to inspect other cells; **Follow head** recenters it.
- **Input** loads an input word and head position, then resets to the program's initial state.
- **Rules → Edit** changes the complete formal program. Saving validates the alphabets, states, initial conditions, and deterministic transition table before creating a reusable custom machine.
- **Journal** shows executed transitions; **Info** explains the formal tuple and lets you inspect rule selection interactively.
- Tilt the phone gently: the dial's lens and bezel reflect a changing lighting direction. Settings include calibration, motion reflections, step haptics, and optional click sounds.

Programs and the current logical configuration save locally. The app reopens paused. Rewind history is local to the current session and holds the last 4,096 transitions; manual edits clear that history while preserving current state and step count.

## Fidelity

Logical transitions follow the formal model one-for-one. A physical phone has finite RAM and integer coordinates: continuous execution pauses after 100,000 steps in one run or 50,000 stored nonblank cells. A resource pause does not imply acceptance, rejection, or mathematical nontermination. Integer overflow leaves the logical configuration unchanged and reports the resource boundary explicitly.

The optical dial combines native Liquid Glass with an artistic convex-lens shader using Snell refraction, wavelength-dependent refractive indices, Schlick Fresnel reflectance, and a procedural grid substrate. It is a visual material model, not measured optics or a reconstruction of the real room. Refraction affects the decorative substrate; read symbols and controls remain stable and readable. Device motion never changes computation. Reduce Motion neutralizes the animated optics; Reduce Transparency supplies an opaque dial surface.

## Build and test

```sh
xcodegen generate
swift test --package-path TuringCore --scratch-path /private/tmp/TuringCore-build
xcodebuild -project TuringMachine.xcodeproj -scheme TuringMachine \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /private/tmp/TuringMachine-derived build
```

The installed Xcode 27 requires its separate official Metal Toolchain component. If it is absent, use `xcodebuild -downloadComponent MetalToolchain`; the verified local component can also be selected with `TOOLCHAINS=com.apple.dt.toolchain.Metal.32023.917`.

`Tests/UITests` exercises atomic step/rewind/reset, tape editing and head placement, and input-to-acceptance behavior. See `Documentation/Validation.md` for this build's actual outcomes and evidence boundaries. The pure Swift engine has an independent executable test suite with exhaustive small-input checks.

## Design references

- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple: Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views)
- [Apple: CMMotionManager](https://developer.apple.com/documentation/coremotion/cmmotionmanager)
- [Busy Beaver Challenge: the three-state tables](https://wiki.bbchallenge.org/wiki/BB(3))

Project name: `TuringMachine` · visible name: **The Turing Machine** · bundle: `com.utkarsh.turingmachine`.


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
