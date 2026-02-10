// Dashboard entry point — mounts React root

switch ReactDOM.Client.createRoot(
  ReactDOM.querySelector("#root")->Option.getOrThrow(~message="Root element #root not found"),
) {
| root => root->ReactDOM.Client.Root.render(<App />)
}
