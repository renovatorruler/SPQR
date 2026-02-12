// LiftKit component bindings — golden-ratio UI framework
// Components installed locally via `npx liftkit add`

module Container = {
  @module("./components/container") @react.component
  external make: (
    ~maxWidth: string=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Card = {
  @module("./components/card") @react.component
  external make: (
    ~scaleFactor: string=?,
    ~variant: string=?,
    ~material: string=?,
    ~bgColor: string=?,
    ~isClickable: bool=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Grid = {
  @module("./components/grid") @react.component
  external make: (
    ~columns: int=?,
    ~gap: string=?,
    ~autoResponsive: bool=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Heading = {
  @module("./components/heading") @react.component
  external make: (
    ~tag: string=?,
    ~fontClass: string=?,
    ~fontColor: string=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Text = {
  @module("./components/text") @react.component
  external make: (
    ~tag: string=?,
    ~fontClass: string=?,
    ~color: string=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Section = {
  @module("./components/section") @react.component
  external make: (
    ~padding: string=?,
    ~py: string=?,
    ~px: string=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Row = {
  @module("./components/row") @react.component
  external make: (
    ~alignItems: string=?,
    ~justifyContent: string=?,
    ~gap: string=?,
    ~wrapChildren: bool=?,
    ~className: string=?,
    ~children: React.element=?,
  ) => React.element = "default"
}

module Badge = {
  @module("./components/badge") @react.component
  external make: (
    ~icon: string=?,
    ~color: string=?,
    ~scale: string=?,
    ~className: string=?,
  ) => React.element = "default"
}

module Icon = {
  @module("./components/icon") @react.component
  external make: (
    ~name: string=?,
    ~fontClass: string=?,
    ~color: string=?,
    ~strokeWidth: int=?,
    ~className: string=?,
  ) => React.element = "default"
}
