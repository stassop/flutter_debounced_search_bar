# Debouncing Flutter SearchAnchor With and Without Third-party Libraries

## Problem

SearchAnchor is probably one of the most useful Material widgets. There’s a small problem however: it doesn’t appear to have any debouncing mechanism.

Debouncing works by introducing a delay between consecutive event occurrences, ensuring that a function is only executed after a specified quiet period following the last event.

In the case of `SearchAnchor` it means that when the user is typing, the `suggestionsBuilder` function is called multiple times, causing flicker and consecutive sets of search results to appear.

The obvious solution would be fetching the results in an async function delayed by a `Timer` and updating the state. Unfortunately, this won’t work because widget state and that of `SearchAnchor` aren’t synced.

## What Does Google Say?
Here’s what Google Gemini tells us about the issue:

> The reason `suggestionBuilder` in `SearchAnchor` might not rebuild even when the list is refreshed is due to a known limitation in Flutter.
>
> **Here’s a breakdown of the issue:**
>
> Normal behavior:
>
> Ideally, any changes to the data used by a widget should trigger a rebuild, ensuring the UI reflects the updated information.
>
> **SearchAnchor limitation:**
>
> In the case of `SearchAnchor`, when the suggestion list is refreshed based on user interaction (e.g., typing in the search bar), the `suggestionBuilder` itself might not automatically rebuild due to the way Flutter manages state updates within this specific widget.

Gemini goes on to suggest using `StatefulBuilder` or `ValueListenableBuilder`, neither of which work.

Great! Now what?

