import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/apis.dart';
import '../models/channel.dart';
import '../models/resource.dart';
import '../helper/dialogs.dart';

class ResourcesScreen extends StatefulWidget {
  final Channel channel;

  const ResourcesScreen({required this.channel, super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _urlController = TextEditingController();
  String _selectedType = 'document';

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _showAddResourceDialog() {
    _titleController.clear();
    _descController.clear();
    _urlController.clear();
    _selectedType = 'document';

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Resource'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g., Course Notes'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Resource description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'URL', hintText: 'https://example.com/resource'),
                ),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  value: _selectedType,
                  isExpanded: true,
                  items: ['document', 'pdf', 'image', 'video', 'link']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedType = val ?? 'document'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final title = _titleController.text.trim();
                final url = _urlController.text.trim();
                if (title.isEmpty || url.isEmpty) {
                  Dialogs.showSnackbar(context, 'Please fill required fields');
                  return;
                }
                await APIs.addResource(
                  widget.channel.id,
                  title,
                  _descController.text.trim(),
                  url,
                  _selectedType,
                );
                if (mounted) {
                  Navigator.pop(context);
                  Dialogs.showSnackbar(context, 'Resource added!');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getResourceIcon(String type) {
    switch (type) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_library;
      case 'link':
        return Icons.language;
      default:
        return Icons.description;
    }
  }

  Color _getResourceColor(String type) {
    switch (type) {
      case 'pdf':
        return Colors.red;
      case 'image':
        return Colors.purple;
      case 'video':
        return Colors.blue;
      case 'link':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreator = widget.channel.createdBy == APIs.user.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.channel.name} - Resources'),
      ),
      body: StreamBuilder(
        stream: APIs.getChannelResources(widget.channel.id),
        builder: (context, AsyncSnapshot snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'No resources yet',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = Map<String, dynamic>.from(docs[index].data() as Map);
              final resource = Resource.fromJson(data);
              final color = _getResourceColor(resource.resourceType);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getResourceIcon(resource.resourceType),
                      color: color,
                      size: 24,
                    ),
                  ),
                  title: Text(
                    resource.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        resource.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        resource.resourceType.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  trailing: SizedBox(
                    width: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: Icon(Icons.open_in_new, color: Colors.blue, size: 20),
                          tooltip: 'Open',
                          onPressed: () async {
                            if (await canLaunchUrl(Uri.parse(resource.url))) {
                              await launchUrl(Uri.parse(resource.url));
                            } else {
                              Dialogs.showSnackbar(context, 'Could not open URL');
                            }
                          },
                        ),
                        if (isCreator)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            tooltip: 'Delete',
                            onPressed: () async {
                              await APIs.deleteResource(widget.channel.id, resource.id);
                              if (mounted) Dialogs.showSnackbar(context, 'Resource deleted');
                            },
                          ),
                      ],
                    ),
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: isCreator
          ? FloatingActionButton(
              onPressed: _showAddResourceDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
