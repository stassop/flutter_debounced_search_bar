# Debouncing Flutter SearchAnchor With and Without Third-party Libraries

## Problem
[SearchAnchor](https://api.flutter.dev/flutter/material/SearchAnchor-class.html) is probably one of the most useful Material widgets. There’s a small problem however: it doesn’t appear to have any debouncing mechanism.

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

## Solution #1: RxDart
[RxDart](https://pub.dev/packages/rxdart) is a powerful package that extends the capabilities of Dart [Streams](https://api.dart.dev/stable/3.3.0/dart-async/Stream-class.html) and [StreamControllers](https://api.dart.dev/stable/3.3.0/dart-async/StreamController-class.html). It also offers a neat and concise way of creating a debounced stream of function calls.

Here’s what the code looks like:
 
```dart
class DebouncedSearchBarState<T> extends State<DebouncedSearchBar<T>> {
  final _searchController = SearchController();
  final _debouncedSearchRx = BehaviorSubject<String>.seeded('');

  Future<Iterable<T>> _search(String query) async {
    if (query.isEmpty) {
      return <T>[];
    }

    try {
      final results = await widget.searchFunction(query);
      return results;
    } catch (error) {
      return <T>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debouncedSearchRx.add(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debouncedSearchRx.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          onTap: () {
            controller.openView();
          },
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final results = await _debouncedSearchRx
            .debounceTime(const Duration(milliseconds: 500))
            .asyncMap((query) => widget.searchFunction(query))
            .first;
        return results.map((result) {
          return ListTile(
            title: Text(result),
            onTap: () {
              widget.onResultSelected?.call(result);
              controller.closeView(controller.text);
            },
          );
        }).toList();
      },
    );
  }
}
```

## Solution #2: Using Completers
What if you want more granular control over your code or you don’t want to use a third-party library? Fortunately, there’s a solution, and it’s actually mentioned in one of the `SearchAnchor` docs examples.

This solution requires two extra parts:

```dart
/// Returns a new function that is a debounced version of the given function.
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer();
    try {
      await debounceTimer!.future;
    } catch (error) {
      print(error); // Should be 'Debounce cancelled' when cancelled.
      return null;
    }
    return function(parameter);
  };
}
```

Next, we need a Timer that acts like a Future but is cancelable:

```dart
// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer() {
    _timer = Timer(_duration, _onComplete);
  }

  late final Timer _timer;
  final Duration _duration = const Duration(milliseconds: 500);
  final Completer<void> _completer = Completer<void>();

  void _onComplete() {
    _completer.complete();
  }

  Future<void> get future => _completer.future;

  bool get isCompleted => _completer.isCompleted;

  void cancel() {
    _timer.cancel();
    _completer.completeError('Debounce cancelled');
  }
}
```

Finally, wrap your search function in the above:

```dart
class DebouncedSearchBarState<T> extends State<DebouncedSearchBar<T>> {
  final _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;

  Future<Iterable<T>> _search(String query) async {
    if (query.isEmpty) {
      return <T>[];
    }

    try {
      final results = await widget.searchFunction(query);
      return results;
    } catch (error) {
      return <T>[];
    }
  }

  @override
  void initState() {
    super.initState();
    _debouncedSearch = _debounce<Iterable<T>?, String>(_search);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return SearchBar(
          controller: controller,
          padding: const MaterialStatePropertyAll<EdgeInsets>(
              EdgeInsets.symmetric(horizontal: 16.0)),
          onTap: () {
            controller.openView();
          },
          leading: const Icon(Icons.search),
          hintText: widget.hintText,
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final results = await _debouncedSearch(controller.text);
        if (results == null) {
          return <Widget>[];
        }
        return results.map((result) {
          return ListTile(
            title: Text(result),
            onTap: () {
              widget.onResultSelected?.call(result);
              controller.closeView(controller.text);
            },
          );
        }).toList();
      },
    );
  }
}
```