import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'SearchBar.dart';

class SearchWidget extends StatefulWidget {
  final Function(String) onSearch;
  final Widget title;
  final Function() cancelCallback;
  final searchClosed;

  SearchWidget(
      {this.onSearch, this.title, this.cancelCallback, this.searchClosed});

  @override
  _SearchWidgetState createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  TextEditingController _textEditingController = TextEditingController();

  @override
  void didUpdateWidget(SearchWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      child: widget.searchClosed
          ? Padding(
              padding: EdgeInsets.only(left: 10, top: 20),
              child: widget.title,
            )
          : Padding(
              padding: const EdgeInsets.only(left: 10.0, top: 10.0),
              child: SearchBar(
                textController: _textEditingController,
                onSearch: widget.onSearch,
                cancel: () {
                  setState(() {
                    _textEditingController.clear();
                    widget.cancelCallback();
                  });
                },
              ),
            ),
    );
  }
}