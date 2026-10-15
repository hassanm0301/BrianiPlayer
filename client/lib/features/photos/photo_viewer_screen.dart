import 'dart:async';

import 'package:briani_api/briani_api.dart' hide Provider;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/client_session.dart';
import '../../core/preferences/preferences_providers.dart';

class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({
    super.key,
    required this.mediaId,
    this.adjacentMediaIds = const [],
  });
  final String mediaId;
  final List<String> adjacentMediaIds;
  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen>
    with WidgetsBindingObserver {
  late String _mediaId;
  Future<Media>? _mediaFuture;
  Future<Uint8List>? _imageFuture;
  Timer? _slideshow;
  bool _playing = false;
  int _index = 0;
  CancelToken? _loadCancel;
  String? _loadedId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mediaId = widget.mediaId;
    _index = widget.adjacentMediaIds
        .indexOf(_mediaId)
        .clamp(
          0,
          widget.adjacentMediaIds.isEmpty
              ? 0
              : widget.adjacentMediaIds.length - 1,
        )
        .toInt();
    _load();
  }

  @override
  void didUpdateWidget(covariant PhotoViewerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        !listEquals(oldWidget.adjacentMediaIds, widget.adjacentMediaIds)) {
      _stop();
      _mediaId = widget.mediaId;
      _index = widget.adjacentMediaIds
          .indexOf(_mediaId)
          .clamp(0, widget.adjacentMediaIds.length);
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadCancel?.cancel();
    _slideshow?.cancel();
    super.dispose();
  }

  void _load() {
    final api = requireActiveApi(ref).getMediaApi();
    _loadCancel?.cancel();
    final cancel = _loadCancel = CancelToken();
    final id = _mediaId;
    _loadedId = null;
    _mediaFuture = api
        .getMedia(id: id, cancelToken: cancel)
        .then((r) => r.data!);
    _imageFuture = api.getImage(id: id, cancelToken: cancel).then((r) {
      if (!cancel.isCancelled && mounted && _mediaId == id) _loadedId = id;
      return r.data!;
    });
    if (mounted) setState(() {});
  }

  void _step(int delta) {
    if (widget.adjacentMediaIds.isEmpty) return;
    _index =
        (_index + delta + widget.adjacentMediaIds.length) %
        widget.adjacentMediaIds.length;
    _mediaId = widget.adjacentMediaIds[_index];
    _load();
  }

  void _toggleSlideshow(int intervalSeconds) {
    if (_playing) {
      _stop();
      return;
    }
    if (widget.adjacentMediaIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Open a folder with multiple photos to start a slideshow.',
          ),
        ),
      );
      return;
    }
    setState(() => _playing = true);
    _slideshow = Timer.periodic(
      Duration(seconds: intervalSeconds.clamp(1, 3600).toInt()),
      (_) {
        if (_loadedId == _mediaId) _step(1);
      },
    );
  }

  void _stop() {
    _slideshow?.cancel();
    _slideshow = null;
    if (mounted && _playing) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    final intervalSeconds =
        ref.watch(userPreferencesProvider).asData?.value.slideshowSeconds ?? 5;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: FutureBuilder<Media>(
          future: _mediaFuture,
          builder: (context, snapshot) => Text(snapshot.data?.name ?? 'Photo'),
        ),
        actions: [
          IconButton(
            tooltip: _playing ? 'Stop slideshow' : 'Start slideshow',
            onPressed: () => _toggleSlideshow(intervalSeconds),
            icon: Icon(_playing ? Icons.pause : Icons.slideshow),
          ),
        ],
      ),
      body: FutureBuilder<Uint8List>(
        future: _imageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    clientError(snapshot.error!),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return const Center(
              child: Text(
                'The photo is empty or unavailable.',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  key: ValueKey(_mediaId),
                  minScale: .5,
                  maxScale: 8,
                  child: Center(
                    child: Image.memory(
                      bytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Text(
                        'This image format could not be displayed.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.adjacentMediaIds.length > 1) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton.filledTonal(
                    tooltip: 'Previous photo',
                    onPressed: () => _step(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton.filledTonal(
                    tooltip: 'Next photo',
                    onPressed: () => _step(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${_index + 1} / ${widget.adjacentMediaIds.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
