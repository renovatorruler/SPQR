// Section header — icon + title row used across all dashboard sections
//
// Two levels enforce the design system pairing of heading tag + font class:
//   Page  → h2 + title1-bold  (top-level sections)
//   Section → h3 + heading-bold (card-level subsections)

type level =
  | Page
  | Section

@react.component
let make = (~title: string, ~icon: string, ~level: level=Page) => {
  let (tag, fontClass) = switch level {
  | Page => (#h2, #"title1-bold")
  | Section => (#h3, #"heading-bold")
  }

  <LiftKit.Row alignItems=#center gap=#xs>
    <LiftKit.Icon name=icon fontClass=#title2 color=#onsurfacevariant />
    <LiftKit.Heading tag fontClass>
      {React.string(title)}
    </LiftKit.Heading>
  </LiftKit.Row>
}
