import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterDownloader.initialize(
    debug: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YTDL',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class TaskDetails {
  final String url;
  final String title;
  final String taskId;

  TaskDetails({
    required this.url,
    required this.title,
    required this.taskId,
  });
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController textEditingController = TextEditingController();
  final List<TaskDetails> tasks = [];
  Queue<TaskDetails> tasksQueue = Queue();

  @override
  void initState() {
    super.initState();
    checkAndRequestPermissions();
    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("YTDL"),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 20,
              ),
              RoundedTextField(controller: textEditingController),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 120,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        ClipboardData? data =
                        await Clipboard.getData('text/plain');
                        if (data != null) {
                          textEditingController.text = data.text!;
                        }
                      },
                      child: const Text("Paste"),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () async {
                        checkAndRequestPermissions();
                        if (textEditingController.text.contains("playlist")) {
                          await downloadPlaylistAsMp3(
                              textEditingController.text);
                        } else {
                          await downloadVideoAsMp3(textEditingController.text);
                        }
                      },
                      child: const Text("Search"),
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 20,
              ),
              Container(
                width: double.infinity,
                alignment: AlignmentDirectional.centerEnd,
                child: ElevatedButton(
                    onPressed: () {
                      FlutterDownloader.cancelAll();
                      setState(() {
                        tasks.clear();
                      });
                    },
                    child: const Text("Cancel All")),
              ),
              SizedBox(
                height: 20,
              ),
              ListView.builder(
                shrinkWrap: true,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  var task = tasks[index];
                  return ListTile(
                    leading: Image.network(task.url),
                    title: Text(task.title),
                    trailing: IconButton(
                      onPressed: () => cancelDownload(task.taskId),
                      icon: const Icon(Icons.clear),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void downloadCallback(String id, int status, int progress) {
    if (status == DownloadTaskStatus.complete) {
      // Download with task ID 'id' is complete
      // You can perform any actions needed when a download is complete
      // For example, start the next download if there are more tasks
      startNextDownload();
      setState(() {
        tasks.removeWhere((task) => task.taskId == id);
      });
    } else if (status == DownloadTaskStatus.failed) {
      // Handle download failure
      print(status);
      setState(() {
        tasks.removeWhere((task) => task.taskId == id);
      });
      print("Download failed for task ID: $id");
    } else if (status == DownloadTaskStatus.canceled) {
      // Handle download cancellation
      print("Download canceled for task ID: $id");
    }
    // Update the progress for the ongoing downloads
    // updateDownloadProgress(id, progress);
  }

  Future<void> startNextDownload() async {
    // Check if there are more tasks in the queue
    if (tasksQueue.isNotEmpty) {
      var nextTask = tasksQueue.removeFirst();
      // await downloadAudio(nextTask.url, nextTask.title);
    }
  }

  Future<void> downloadVideoAsMp3(String videoUrl) async {
    try {
      var yt = YoutubeExplode();
      var video = await yt.videos.get(videoUrl);
      var manifest = await yt.videos.streamsClient.getManifest(video.id);
      var audioStream = manifest.audioOnly.withHighestBitrate();
      yt.close();
      String sanitizedTitle = video.title.replaceAll("/", "_");
      String? taskId = await FlutterDownloader.enqueue(
        url: audioStream.url.toString(),
        savedDir: '/storage/emulated/0/Download/',
        fileName: '$sanitizedTitle.mp3',
        showNotification: true,
        openFileFromNotification: true,
      );

      if (taskId != null) {
        setState(() {
          tasks.add(TaskDetails(
            url: video.thumbnails.lowResUrl,
            title: video.title,
            taskId: taskId,
          ));
        });
      } else {
        print("Error starting the download.");
      }

      print("Download started with task ID: $taskId");
    } catch (e) {
      // Handle exceptions
      print("Error downloading video as MP3: $e");
    }
  }

  Future<void> downloadPlaylistAsMp3(String playlistUrl) async {
    try {
      var yt = YoutubeExplode();
      var playlist = await yt.playlists.get(playlistUrl);

      await for (var video in yt.playlists.getVideos(playlist.id)) {
        var manifest = await yt.videos.streamsClient.getManifest(video.id);
        var audioStream = manifest.audioOnly.withHighestBitrate();
        String sanitizedTitle = video.title.replaceAll("/", "_");
        String? downloadTask = await FlutterDownloader.enqueue(
          url: audioStream.url.toString(),
          savedDir: '/storage/emulated/0/Download/',
          fileName: '$sanitizedTitle.mp3',
          showNotification: true,
          openFileFromNotification: true,
        );

        if (downloadTask != null) {
          setState(() {
            tasks.add(TaskDetails(
              url: video.thumbnails.lowResUrl,
              title: video.title,
              taskId: downloadTask,
            ));
          });
        } else {
          print("Error starting the download.");
        }

        print("Download started for: $sanitizedTitle");
      }
      yt.close();

      print("Playlist download complete!");
    } catch (e) {
      // Handle exceptions
      print("Error downloading playlist: $e");
    }
  }

  Future<void> cancelDownload(String taskId) async {
    await FlutterDownloader.cancel(taskId: taskId);
    setState(() {
      tasks.removeWhere((task) => task.taskId == taskId);
    });
  }

  Future<void> checkAndRequestPermissions() async {
    try {
      var storageStatus = await Permission.manageExternalStorage.status;

      if (!storageStatus.isGranted) {
        var storageResult = await Permission.manageExternalStorage.request();

        if (storageResult != PermissionStatus.granted) {
          Map<Permission, PermissionStatus> statuses = await [
            Permission.storage,
            Permission.manageExternalStorage,
          ].request();
          print("Storage permission denied or restricted");
        }
      }

      var notificationStatus = await Permission.notification.status;

      if (!notificationStatus.isGranted) {
        var notificationResult = await Permission.notification.request();

        if (notificationResult != PermissionStatus.granted) {
          // Handle denied or restricted notification permission
          print("Notification permission denied or restricted");
        }
      }

      print("Storage Permission Granted: ${storageStatus.isGranted}");
      print("Notification Permission Granted: ${notificationStatus.isGranted}");

    } catch (e) {
      print("Error checking or requesting permissions: $e");
    }
  }
}

class RoundedTextField extends StatelessWidget {
  final TextEditingController controller;

  RoundedTextField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        filled: true,
        hintText: 'Paste video or playlist url here',
        contentPadding: EdgeInsets.symmetric(vertical: 18.0, horizontal: 32.0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
