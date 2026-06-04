import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/main_scaffold.dart';
import '../models/word_list.dart';
import '../providers/word_list_provider.dart';

class WordListScreen extends StatefulWidget {
  const WordListScreen({super.key});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WordListProvider>().loadWordLists();
    });
  }

  Future<void> _createList() async {
    final result = await showDialog<_CreateListResult>(
      context: context,
      builder: (_) => const _CreateListDialog(),
    );
    if (!mounted || result == null) return;

    final provider = context.read<WordListProvider>();
    final success = await provider.createList(result.name, result.description);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Đã tạo danh sách từ'
              : provider.errorMessage ?? 'Không thể tạo danh sách từ',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WordListProvider>();

    return MainScaffold(
      currentIndex: 2,
      appBar: AppBar(title: const Text('Vocabulary')),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
            child: CustomButton(
              label: 'Tạo danh sách từ',
              icon: Icons.add_rounded,
              onPressed: _createList,
            ),
          ),
          Expanded(
            child:
                provider.isLoading
                    ? const LoadingWidget(message: 'Đang tải danh sách...')
                    : provider.errorMessage != null
                    ? ErrorStateWidget(
                      title: 'Không tải được danh sách',
                      message: provider.errorMessage!,
                      onRetry: provider.loadWordLists,
                    )
                    : provider.wordLists.isEmpty
                    ? const EmptyStateWidget(
                      title: 'Chưa có danh sách từ',
                      message: 'Tạo danh sách TOEIC, B1, IELTS... để bắt đầu.',
                      icon: Icons.folder_copy_rounded,
                    )
                    : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: provider.wordLists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final list = provider.wordLists[index];
                        return _WordListCard(
                          list: list,
                          onTap: () {
                            provider.selectList(list);
                            Navigator.pushNamed(
                              context,
                              AppRoutes.wordListDetail,
                              arguments: list,
                            );
                          },
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _WordListCard extends StatelessWidget {
  const _WordListCard({required this.list, required this.onTap});

  final WordList list;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: colors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.folder_rounded, color: colors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  list.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  list.description.trim().isEmpty
                      ? 'Không có ghi chú'
                      : list.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  '${list.wordCount} từ',
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}

class _CreateListDialog extends StatefulWidget {
  const _CreateListDialog();

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tạo danh sách từ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Tên danh sách'),
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
              _CreateListResult(
                name: name,
                description: _descriptionController.text.trim(),
              ),
            );
          },
          child: const Text('Tạo'),
        ),
      ],
    );
  }
}

class _CreateListResult {
  const _CreateListResult({required this.name, required this.description});

  final String name;
  final String description;
}
