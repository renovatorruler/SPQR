// LiftKit component bindings — golden-ratio UI framework
// Components installed locally via `npx liftkit add`
//
// Poly variant types ensure compile-time validity of prop values.
// Poly variant tags compile to their string name at the JS boundary (zero overhead).

// -- Shared token types --

// Design system spacing scale
type sizeUnit = [
  | #"3xs"
  | #"2xs"
  | #xs
  | #sm
  | #md
  | #lg
  | #xl
  | #"2xl"
  | #"3xl"
  | #"4xl"
]

// Material Design 3 color tokens used across components
type color = [
  | #primary
  | #error
  | #onsurface
  | #onsurfacevariant
  | #onerrorcontainer
  | #surfacecontainerlow
  | #errorcontainer
  | #transparent
  | #currentColor
]

// Typography class tokens
type fontClass = [
  | #display1
  | #"display1-bold"
  | #display2
  | #"display2-bold"
  | #title1
  | #"title1-bold"
  | #title2
  | #"title2-bold"
  | #title3
  | #"title3-bold"
  | #heading
  | #"heading-bold"
  | #subheading
  | #"subheading-bold"
  | #body
  | #"body-bold"
  | #"body-mono"
  | #callout
  | #"callout-bold"
  | #label
  | #"label-bold"
  | #caption
  | #"caption-bold"
  | #capline
  | #"capline-bold"
]

// -- Component bindings --

module Container = {
  type maxWidth = [#xs | #sm | #md | #lg | #xl | #none | #auto]

  @module("./components/container") @react.component
  external make: (
    ~maxWidth: maxWidth=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Card = {
  type variant = [#fill | #outline | #transparent]
  type material = [#flat | #glass]

  @module("./components/card") @react.component
  external make: (
    ~scaleFactor: string=?,
    ~variant: variant=?,
    ~material: material=?,
    ~bgColor: color=?,
    ~isClickable: bool=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Grid = {
  @module("./components/grid") @react.component
  external make: (
    ~columns: int=?,
    ~gap: sizeUnit=?,
    ~autoResponsive: bool=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Heading = {
  type tag = [#h1 | #h2 | #h3 | #h4 | #h5 | #h6]

  @module("./components/heading") @react.component
  external make: (
    ~tag: tag=?,
    ~fontClass: fontClass=?,
    ~fontColor: color=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Text = {
  type tag = [#div | #span | #p | #label]

  @module("./components/text") @react.component
  external make: (
    ~tag: tag=?,
    ~fontClass: fontClass=?,
    ~color: color=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Section = {
  type padding = [#xs | #sm | #md | #lg | #xl | #none]

  @module("./components/section") @react.component
  external make: (
    ~padding: padding=?,
    ~py: padding=?,
    ~px: padding=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Row = {
  type alignItems = [#start | #center | #"end" | #stretch]
  type justifyContent = [#start | #center | #"end" | #"space-between" | #"space-around"]

  @module("./components/row") @react.component
  external make: (
    ~alignItems: alignItems=?,
    ~justifyContent: justifyContent=?,
    ~gap: sizeUnit=?,
    ~wrapChildren: bool=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Badge = {
  type scale = [#md | #lg]

  @module("./components/badge") @react.component
  external make: (
    ~icon: string=?,
    ~color: color=?,
    ~scale: scale=?,
    ~className: string=?,
  ) => React.element = "default"
}

module Icon = {
  @module("./components/icon") @react.component
  external make: (
    ~name: string=?,
    ~fontClass: fontClass=?,
    ~color: color=?,
    ~strokeWidth: int=?,
    ~className: string=?,
  ) => React.element = "default"
}
