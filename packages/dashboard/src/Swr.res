// SWR bindings — minimal typed interface for data fetching hooks
//
// SWR provides stale-while-revalidate caching: components render instantly
// with cached data, then revalidate in the background.

type swrResponse<'data> = {
  data: option<'data>,
  error: option<JsExn.t>,
  isLoading: bool,
  isValidating: bool,
}

// Generic SWR hook — fetcher is a URL → promise<'data> function
@module("swr")
external useSWR: (string, string => promise<'data>) => swrResponse<'data> = "default"
