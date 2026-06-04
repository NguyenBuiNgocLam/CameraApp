import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../../../core/widgets/vocabulary_card.dart';
import '../../../models/vocabulary_item.dart';
import '../../../providers/vocabulary_provider.dart';
import '../../vocabulary_learning/providers/vocabulary_learning_provider.dart';
import '../models/word_list.dart';
import '../providers/word_list_provider.dart';
import '../widgets/add_vocabulary_dialog.dart';
import '../widgets/import_csv_dialog.dart';

class WordListDetailScreen extends StatefulWidget {
  const WordListDetailScreen({required this.list, super.key});

  final WordList list;

  @override
  State<WordListDetailScreen> createState() => _WordListDetailScreenState();
}

class _WordListDetailScreenState extends State<WordListDetailScreen> {
  bool _loaded = false;
  late WordList _list;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WordListProvider>().selectList(_list);
      context.read<VocabularyProvider>().load();
    });
  }

  List<VocabularyItem> _itemsForList(List<VocabularyItem> items) {
    return items.where((item) => item.listId == _list.id).toList();
  }

  Future<void> _openAddVocabularyDialog() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AddVocabularyDialog(initialListId: _list.id),
    );
    if (!mounted || saved != true) return;
    await context.read<WordListProvider>().refreshWordCount();
    if (!mounted) return;
    _syncCurrentList();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Saved successfully')));
  }

  Future<void> _openImportCsvDialog() async {
    final imported = await showDialog<bool>(
      context: context,
      builder: (_) => ImportCsvDialog(initialListId: _list.id),
    );
    if (!mounted || imported != true) return;
    await context.read<WordListProvider>().refreshWordCount();
    if (!mounted) return;
    _syncCurrentList();
  }

  Future<void> _openEditListDialog() async {
    final result = await showDialog<_EditListResult>(
      context: context,
      builder: (_) => _EditListDialog(list: _list),
    );
    if (!mounted || result == null) return;

    final provider = context.read<WordListProvider>();
    final success = await provider.updateList(
      list: _list,
      name: result.name,
      description: result.description,
    );
    if (!mounted) return;

    if (success) {
      _syncCurrentList();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã cập nhật mục'
              : provider.errorMessage ?? 'Không thể cập nhật mục',
        ),
      ),
    );
  }

  Future<void> _deleteList(List<VocabularyItem> items) async {
    if (items.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chỉ có thể xóa mục trống. Hãy xóa từ trong mục trước.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Xóa mục này?'),
            content: Text('Mục "${_list.name}" đang trống và sẽ bị xóa.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Xóa'),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true) return;

    final provider = context.read<WordListProvider>();
    final success = await provider.deleteList(_list);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Đã xóa mục' : provider.errorMessage ?? 'Không thể xóa mục',
        ),
      ),
    );
    if (success) {
      Navigator.pop(context);
    }
  }

  Future<void> _startLearning() async {
    final provider = context.read<VocabularyLearningProvider>();
    await provider.startLearning(listId: _list.id);
    if (!mounted) return;

    if (provider.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Danh sách này chưa có từ.'),
        ),
      );
      return;
    }

    Navigator.pushNamed(context, AppRoutes.vocabularyLearningPractice);
  }

  void _syncCurrentList() {
    final provider = context.read<WordListProvider>();
    final updated = provider.wordLists.where((list) => list.id == _list.id);
    if (updated.isEmpty) return;
    setState(() => _list = updated.first);
  }

  @override
  Widget build(BuildContext context) {
    final vocabulary = context.watch<VocabularyProvider>();
    final items = _itemsForList(vocabulary.items);

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(
        title: Text(_list.name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Tùy chọn mục',
            onSelected: (value) {
              if (value == 'edit') {
                _openEditListDialog();
              } else if (value == 'delete') {
                _deleteList(items);
              }
            },
            itemBuilder:
                (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Sửa tên mục'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete_outline_rounded),
                      title: Text('Xóa mục'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: CustomButton(
                        label: 'Học',
                        icon: Icons.school_rounded,
                        onPressed: _startLearning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CustomButton(
                        label: 'Thêm từ',
                        icon: Icons.add_rounded,
                        style: CustomButtonStyle.secondary,
                        onPressed: _openAddVocabularyDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                CustomButton(
                  label: 'Nhập CSV',
                  icon: Icons.upload_file_rounded,
                  style: CustomButtonStyle.outline,
                  onPressed: _openImportCsvDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child:
                vocabulary.isLoading
                    ? const LoadingWidget(message: 'Loading vocabulary...')
                    : vocabulary.errorMessage != null
                    ? ErrorStateWidget(
                      title: 'Cannot load vocabulary',
                      message: vocabulary.errorMessage!,
                      onRetry: context.read<VocabularyProvider>().load,
                    )
                    : items.isEmpty
                    ? const EmptyStateWidget(
                      title: 'Danh sách chưa có từ',
                      message: 'Thêm thủ công hoặc nhập CSV để bắt đầu.',
                      icon: Icons.menu_book_rounded,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return VocabularyCard(
                          item: item,
                          showDelete: true,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                AppRoutes.vocabularyDetail,
                                arguments: item,
                              ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _EditListDialog extends StatefulWidget {
  const _EditListDialog({required this.list});

  final WordList list;

  @override
  State<_EditListDialog> createState() => _EditListDialogState();
}

class _EditListDialogState extends State<_EditListDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
    _descriptionController = TextEditingController(
      text: widget.list.description,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sửa mục'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Tên mục'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
            minLines: 1,
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _EditListResult(
                name: name,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _EditListResult {
  const _EditListResult({required this.name, required this.description});

  final String name;
  final String description;
}
