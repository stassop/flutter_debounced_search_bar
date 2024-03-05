# Debouncing Flutter SearchAnchor
## With and Without Third-party Libraries

### Problem

`SearchAnchor` is probably one of the most useful Material widgets. There’s a small problem however: it doesn’t appear to have any debouncing mechanism.

Debouncing works by introducing a delay between consecutive event occurrences, ensuring that a function is only executed after a specified quiet period following the last event.

In the case of `SearchAnchor` it means that when the user is typing, the suggestionsBuilder function is called multiple times, causing flicker and consecutive sets of search results to appear.

The obvious solution would be fetching the results in an async function delayed by a `Timer` and updating the state. Unfortunately, this won’t work because widget state and that of `SearchAnchor` aren’t synced.

