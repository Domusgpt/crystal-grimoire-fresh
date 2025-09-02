import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Optimized video service for Crystal Grimoire meditation content
/// Handles video streaming, caching, and premium access
class OptimizedVideoService {
  static OptimizedVideoService? _instance;
  static OptimizedVideoService get instance => _instance ??= OptimizedVideoService._();
  OptimizedVideoService._();

  final Map<String, VideoPlayerController> _controllers = {};
  bool _isUserPremium = false;

  /// Available meditation videos
  static const Map<String, VideoMetadata> videos = {
    'amethyst_meditation': VideoMetadata(
      title: 'Amethyst Deep Meditation',
      description: 'Calming meditation with amethyst energy activation',
      duration: '15:00',
      isPremium: false,
      thumbnailPath: 'assets/images/crystals/amethyst_thumb.jpg',
      videoPath: 'assets/videos/amethyst_meditation.mp4',
      firebaseStoragePath: 'meditation_videos/amethyst_meditation_optimized.mp4',
      tags: ['meditation', 'amethyst', 'third_eye', 'intuition'],
    ),
    'labradorite_transformation': VideoMetadata(
      title: 'Labradorite Transformation Journey',
      description: 'Powerful transformation meditation with labradorite guidance',
      duration: '20:00',
      isPremium: true,
      thumbnailPath: 'assets/images/crystals/labradorite_thumb.jpg',
      videoPath: 'assets/videos/labradorite_transformation.mp4',
      firebaseStoragePath: 'meditation_videos/labradorite_transformation_optimized.mp4',
      tags: ['transformation', 'labradorite', 'advanced', 'spiritual_growth'],
    ),
    'crystal_healing_basics': VideoMetadata(
      title: 'Crystal Healing Fundamentals',
      description: 'Learn the basics of crystal healing and energy work',
      duration: '12:00',
      isPremium: false,
      thumbnailPath: 'assets/images/crystals/healing_thumb.jpg',
      videoPath: 'assets/videos/crystal_healing_basics.mp4',
      firebaseStoragePath: 'meditation_videos/crystal_healing_basics_optimized.mp4',
      tags: ['healing', 'basics', 'education', 'beginner'],
    ),
    'full_moon_ritual': VideoMetadata(
      title: 'Full Moon Crystal Ritual',
      description: 'Complete full moon ritual with crystal charging',
      duration: '25:00',
      isPremium: true,
      thumbnailPath: 'assets/images/crystals/full_moon_thumb.jpg',
      videoPath: 'assets/videos/full_moon_ritual.mp4',
      firebaseStoragePath: 'meditation_videos/full_moon_ritual_optimized.mp4',
      tags: ['ritual', 'full_moon', 'charging', 'advanced'],
    ),
  };

  /// Initialize video service
  Future<void> initialize() async {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.fetchAndActivate();
    
    print('🎬 Optimized Video Service initialized');
  }

  /// Update user subscription status
  void updateUserSubscription(bool isPremium) {
    _isUserPremium = isPremium;
    print('🎬 User premium status: $_isUserPremium');
  }

  /// Get video controller with optimization
  Future<VideoPlayerController?> getVideoController(String videoId) async {
    if (_controllers.containsKey(videoId)) {
      return _controllers[videoId];
    }

    final videoMetadata = videos[videoId];
    if (videoMetadata == null) {
      print('❌ Video not found: $videoId');
      return null;
    }

    // Check premium access
    if (videoMetadata.isPremium && !_isUserPremium) {
      print('🔒 Premium video requires subscription: $videoId');
      return null;
    }

    try {
      VideoPlayerController controller;
      
      // Try Firebase Storage first for optimized versions
      try {
        final downloadUrl = await FirebaseStorage.instance
            .ref(videoMetadata.firebaseStoragePath)
            .getDownloadURL();
        controller = VideoPlayerController.network(downloadUrl);
        print('📡 Loading video from Firebase Storage: $videoId');
      } catch (e) {
        // Fallback to local asset
        controller = VideoPlayerController.asset(videoMetadata.videoPath);
        print('📱 Loading video from local asset: $videoId');
      }

      await controller.initialize();
      _controllers[videoId] = controller;
      
      return controller;
    } catch (e) {
      print('❌ Failed to load video $videoId: $e');
      return null;
    }
  }

  /// Get available videos for user
  List<VideoMetadata> getAvailableVideos() {
    return videos.values.where((video) {
      return !video.isPremium || _isUserPremium;
    }).toList();
  }

  /// Get premium videos
  List<VideoMetadata> getPremiumVideos() {
    return videos.values.where((video) => video.isPremium).toList();
  }

  /// Check if video is accessible
  bool isVideoAccessible(String videoId) {
    final video = videos[videoId];
    if (video == null) return false;
    return !video.isPremium || _isUserPremium;
  }

  /// Dispose specific video controller
  void disposeVideo(String videoId) {
    if (_controllers.containsKey(videoId)) {
      _controllers[videoId]?.dispose();
      _controllers.remove(videoId);
      print('🗑️ Disposed video controller: $videoId');
    }
  }

  /// Dispose all video controllers
  void disposeAll() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    print('🗑️ Disposed all video controllers');
  }
}

/// Video metadata class
class VideoMetadata {
  final String title;
  final String description;
  final String duration;
  final bool isPremium;
  final String thumbnailPath;
  final String videoPath;
  final String firebaseStoragePath;
  final List<String> tags;

  const VideoMetadata({
    required this.title,
    required this.description,
    required this.duration,
    required this.isPremium,
    required this.thumbnailPath,
    required this.videoPath,
    required this.firebaseStoragePath,
    required this.tags,
  });
}

/// Optimized video player widget
class CrystalGrimoireVideoPlayer extends StatefulWidget {
  final String videoId;
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onVideoComplete;

  const CrystalGrimoireVideoPlayer({
    Key? key,
    required this.videoId,
    this.autoPlay = false,
    this.showControls = true,
    this.onVideoComplete,
  }) : super(key: key);

  @override
  State<CrystalGrimoireVideoPlayer> createState() => _CrystalGrimoireVideoPlayerState();
}

class _CrystalGrimoireVideoPlayerState extends State<CrystalGrimoireVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final controller = await OptimizedVideoService.instance.getVideoController(widget.videoId);
      
      if (controller == null) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Video not available or requires premium access';
          _isLoading = false;
        });
        return;
      }

      _controller = controller;
      
      // Set up video completion listener
      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration) {
          widget.onVideoComplete?.call();
        }
      });

      if (widget.autoPlay) {
        await _controller!.play();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load video: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading meditation video...'),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage ?? 'Unknown error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadVideo,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: Text('Video not available'));
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        children: [
          VideoPlayer(_controller!),
          if (widget.showControls)
            Positioned.fill(
              child: VideoPlayerControls(controller: _controller!),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Don't dispose the controller here - let the service manage it
    super.dispose();
  }
}

/// Custom video player controls
class VideoPlayerControls extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoPlayerControls({Key? key, required this.controller}) : super(key: key);

  @override
  State<VideoPlayerControls> createState() => _VideoPlayerControlsState();
}

class _VideoPlayerControlsState extends State<VideoPlayerControls> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: AnimatedOpacity(
        opacity: _showControls ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          color: Colors.black26,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      widget.controller.value.isPlaying
                          ? widget.controller.pause()
                          : widget.controller.play();
                    });
                  },
                  icon: Icon(
                    widget.controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}