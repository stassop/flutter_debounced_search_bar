import 'package:flutter/material.dart';
import 'dart:async'; 

/// This is a simplified version of debounced search based on the following example:
/// https://api.flutter.dev/flutter/material/Autocomplete-class.html?v=1.0.20#material.Autocomplete.5
typedef _Debounceable<S, T> = Future<S?> Function(T parameter);

/// Returns a new function that is a debounced version of the given function.
/// This means that the original function will be called only after no calls
/// have been made for the given Duration.
_Debounceable<S, T> _debounce<S, T>(_Debounceable<S?, T> function) {
  _DebounceTimer? debounceTimer;

  return (T parameter) async {
    if (debounceTimer != null && !debounceTimer!.isCompleted) {
      debounceTimer!.cancel();
    }
    debounceTimer = _DebounceTimer(duration: const Duration(milliseconds: 500));
    try {
      await debounceTimer!.future;
    } catch (error) {
      print(error); // Should be 'Debounce cancelled' when cancelled.
      return null;
    }
    return function(parameter);
  };
}

// A wrapper around Timer used for debouncing.
class _DebounceTimer {
  _DebounceTimer({required this.duration}) {
    _timer = Timer(duration, _onComplete);
  }

  late final Timer _timer;
  final Duration duration;
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

class DebouncedSearchBar<T> extends StatefulWidget {
  const DebouncedSearchBar({
    super.key,
    this.hintText,
    required this.resultTitleBuilder,
    this.resultSubtitleBuilder,
    this.resultThumbnailBuilder,
    required this.onResultSelected,
    required this.searchFunction,
  });

  final String? hintText;
  final Widget Function(T result) resultTitleBuilder;
  final Widget Function(T result)? resultSubtitleBuilder;
  final Widget Function(T result)? resultThumbnailBuilder;
  final Function(T result)? onResultSelected;
  final Future<Iterable<T>> Function(String query) searchFunction;

  @override
  State<StatefulWidget> createState() => DebouncedSearchBarState<T>();
}

class DebouncedSearchBarState<T> extends State<DebouncedSearchBar<T>> {
  final _searchController = SearchController();
  late final _Debounceable<Iterable<T>?, String> _debouncedSearch;

  _selectResult(T result) {
    widget.onResultSelected?.call(result);
  }

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
            title: widget.resultTitleBuilder(result),
            subtitle: widget.resultSubtitleBuilder?.call(result),
            leading: widget.resultThumbnailBuilder?.call(result),
            onTap: () {
              _selectResult(result);
              controller.closeView(controller.text);
            },
          );
        }).toList();
      },
    );
  }
}