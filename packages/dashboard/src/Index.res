switch ReactDOM.querySelector("#root") {
| Some(root) => ReactDOM.Client.createRoot(root)->ReactDOM.Client.Root.render(<App />)
| None => Console.error("Could not find #root element")
}
