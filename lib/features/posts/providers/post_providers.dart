import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/common.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/post.dart';
import '../../../core/models/taxonomy.dart';
import '../../../shared/providers/paged_notifier.dart';
import '../../taxonomy/data/taxonomy_api.dart';
import '../data/post_api.dart';

/// 文章列表筛选条件。
class PostFilter {
  const PostFilter({
    this.status,
    this.visible,
    this.key,
    this.tagId,
    this.categoryId,
    this.sort,
  });

  final PostStatus? status;
  final PostVisible? visible;
  final String? key;
  final int? tagId;
  final int? categoryId;
  final PostSort? sort;
}

/// 文章列表状态管理。
class PostListNotifier extends PagedNotifier<Post> {
  PostFilter _filter = const PostFilter();

  /// 当前筛选条件。
  PostFilter get filter => _filter;

  @override
  Future<Pager<Post>> fetchPage(int page) {
    return ref.read(postApiProvider).posts(
          page: page,
          size: 10,
          status: _filter.status,
          visible: _filter.visible,
          key: _filter.key,
          tagId: _filter.tagId,
          categoryId: _filter.categoryId,
          sort: _filter.sort,
        );
  }

  /// 切换文章状态（Tab）并重置分页。
  Future<void> setStatus(PostStatus? status) async {
    _filter = PostFilter(
      status: status,
      visible: _filter.visible,
      key: _filter.key,
      tagId: _filter.tagId,
      categoryId: _filter.categoryId,
      sort: _filter.sort,
    );
    await reload();
  }

  /// 应用高级筛选（保留当前状态 Tab）。
  Future<void> applyFilter({
    PostVisible? visible,
    String? key,
    int? tagId,
    int? categoryId,
    PostSort? sort,
  }) async {
    _filter = PostFilter(
      status: _filter.status,
      visible: visible,
      key: key,
      tagId: tagId,
      categoryId: categoryId,
      sort: sort,
    );
    await reload();
  }
}

/// 文章列表提供者。
final postListProvider =
    AsyncNotifierProvider<PostListNotifier, PagedState<Post>>(
  PostListNotifier.new,
);

/// 全部分类（文章设置表单等场景使用）。
final allCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(taxonomyApiProvider).categories(),
);

/// 全部标签（文章设置表单等场景使用）。
final allTagsProvider = FutureProvider.autoDispose<List<Tag>>(
  (ref) => ref.watch(taxonomyApiProvider).tags(),
);

/// 编辑器当前查看的内容类型。
enum EditorTab { publish, draft }

/// 文章编辑器状态。
class EditorState {
  const EditorState({
    required this.post,
    required this.contents,
    required this.content,
    required this.tab,
    this.draftName,
    this.loadingContent = false,
    this.saving = false,
    this.dirty = false,
  });

  /// 文章信息。
  final Post post;

  /// 正文与草稿元信息。
  final List<PostContentMeta> contents;

  /// 编辑器中的文本。
  final String content;

  /// 当前编辑的内容类型。
  final EditorTab tab;

  /// 当前编辑的草稿名（tab 为 draft 时有效）。
  final String? draftName;

  /// 是否正在加载内容（切换正文/草稿）。
  final bool loadingContent;

  /// 是否正在保存。
  final bool saving;

  /// 内容是否有未保存修改。
  final bool dirty;

  EditorState copyWith({
    List<PostContentMeta>? contents,
    String? content,
    EditorTab? tab,
    String? draftName,
    bool? loadingContent,
    bool? saving,
    bool? dirty,
  }) =>
      EditorState(
        post: post,
        contents: contents ?? this.contents,
        content: content ?? this.content,
        tab: tab ?? this.tab,
        draftName: draftName,
        loadingContent: loadingContent ?? this.loadingContent,
        saving: saving ?? this.saving,
        dirty: dirty ?? this.dirty,
      );
}

/// 文章编辑器状态管理（按文章 ID 隔离）。
class PostEditorNotifier extends AsyncNotifier<EditorState> {
  PostEditorNotifier(this.postId);

  /// 编辑的文章 ID。
  final int postId;

  @override
  Future<EditorState> build() async {
    final api = ref.read(postApiProvider);

    final post = await api.post(postId);
    if (post == null) {
      throw StateError('文章不存在或已被删除');
    }
    final contents = await api.postContents(postId);
    final publish = await api.postPublishContent(postId);

    return EditorState(
      post: post,
      contents: contents,
      content: publish.content,
      tab: EditorTab.publish,
    );
  }

  /// 刷新编辑器文本（用户输入）。
  void updateContent(String text) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(content: text, dirty: true));
  }

  /// 保存正文。
  Future<void> savePublish() async {
    final current = state.value;
    if (current == null || current.saving || current.tab != EditorTab.publish) {
      return;
    }
    state = AsyncData(current.copyWith(saving: true));
    final content = current.content;
    try {
      await ref.read(postApiProvider).updatePublish(postId, content);
      final contents = await ref.read(postApiProvider).postContents(postId);
      // 保存期间用户可能继续输入：以最新文本回写 dirty，避免误标为已保存
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          saving: false,
          dirty: latest.content != content,
          contents: contents,
        ),
      );
    } catch (_) {
      // 失败时保留原数据并抛出：若置为 AsyncError 会丢失 value，
      // 整页被错误占位覆盖导致未保存内容丢失，且 UI 无法感知错误
      state = AsyncData(current.copyWith(saving: false));
      rethrow;
    }
  }

  /// 加载草稿到编辑器。
  Future<void> loadDraft(String draftName) async {
    final current = state.value;
    if (current == null || current.loadingContent) return;
    state = AsyncData(current.copyWith(loadingContent: true));
    try {
      final draft =
          await ref.read(postApiProvider).postDraftContent(postId, draftName);
      state = AsyncData(
        current.copyWith(
          content: draft.content,
          tab: EditorTab.draft,
          draftName: draftName,
          loadingContent: false,
          dirty: false,
        ),
      );
    } catch (_) {
      // 失败时复位加载标记，避免 UI 永久卡在加载态、无法切换正文/草稿
      state = AsyncData(current.copyWith(loadingContent: false));
      rethrow;
    }
  }

  /// 切回正文编辑。
  Future<void> loadPublish() async {
    final current = state.value;
    if (current == null || current.loadingContent) return;
    state = AsyncData(current.copyWith(loadingContent: true));
    try {
      final publish =
          await ref.read(postApiProvider).postPublishContent(postId);
      state = AsyncData(
        current.copyWith(
          content: publish.content,
          tab: EditorTab.publish,
          draftName: null,
          loadingContent: false,
          dirty: false,
        ),
      );
    } catch (_) {
      // 失败时复位加载标记，避免 UI 永久卡在加载态、无法切换正文/草稿
      state = AsyncData(current.copyWith(loadingContent: false));
      rethrow;
    }
  }

  /// 将编辑器当前内容另存为草稿。
  Future<void> saveDraft(String draftName) async {
    final current = state.value;
    if (current == null || current.saving) return;
    state = AsyncData(current.copyWith(saving: true));
    final content = current.content;
    try {
      if (current.tab == EditorTab.draft && current.draftName == draftName) {
        // 更新当前草稿
        await ref.read(postApiProvider).updateDraft(
              postId: postId,
              content: current.content,
              draftName: draftName,
            );
      } else {
        // 新建草稿
        await ref.read(postApiProvider).addDraft(
              postId: postId,
              content: current.content,
              draftName: draftName,
            );
      }
      final contents = await ref.read(postApiProvider).postContents(postId);
      // 保存期间用户可能继续输入：以最新文本回写 dirty，避免误标为已保存
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          saving: false,
          contents: contents,
          tab: EditorTab.draft,
          draftName: draftName,
          dirty: latest.content != content,
        ),
      );
    } catch (_) {
      // 失败时保留原数据并抛出：若置为 AsyncError 会丢失 value，
      // 整页被错误占位覆盖导致未保存内容丢失，且 UI 无法感知错误
      state = AsyncData(current.copyWith(saving: false));
      rethrow;
    }
  }

  /// 删除草稿。
  Future<void> deleteDraft(String draftName) async {
    await ref.read(postApiProvider).deleteDrafts(postId, [draftName]);
    final current = state.value;
    if (current == null) return;
    final contents = await ref.read(postApiProvider).postContents(postId);
    if (current.tab == EditorTab.draft && current.draftName == draftName) {
      // 删除的是正在编辑的草稿，切回正文
      final publish = await ref.read(postApiProvider).postPublishContent(postId);
      state = AsyncData(
        current.copyWith(
          contents: contents,
          content: publish.content,
          tab: EditorTab.publish,
          draftName: null,
          dirty: false,
        ),
      );
    } else {
      state = AsyncData(current.copyWith(contents: contents));
    }
  }

  /// 草稿重命名。
  Future<void> renameDraft({
    required String oldName,
    required String newName,
  }) async {
    await ref.read(postApiProvider).updateDraftName(
          postId: postId,
          oldName: oldName,
          newName: newName,
        );
    final current = state.value;
    if (current == null) return;
    final contents = await ref.read(postApiProvider).postContents(postId);
    final isActive = current.tab == EditorTab.draft &&
        current.draftName == oldName;
    state = AsyncData(
      current.copyWith(
        contents: contents,
        // 重命名的不是当前编辑的草稿时，保持当前草稿名不变
        // （copyWith 的 draftName 为直接覆盖，传 null 会误清状态）
        draftName: isActive ? newName : current.draftName,
      ),
    );
  }

  /// 将指定草稿转换为正文。
  Future<void> publishDraft({
    required String draftName,
    required bool deleteContent,
    String? contentName,
  }) async {
    await ref.read(postApiProvider).draft2Content(
          postId: postId,
          draftName: draftName,
          deleteContent: deleteContent,
          contentName: contentName,
        );
    // 转换后切回正文并加载最新内容
    await loadPublish();
  }

  /// 文章设置更新后刷新文章信息。
  Future<void> refreshPost() async {
    final post = await ref.read(postApiProvider).post(postId);
    final current = state.value;
    if (post == null || current == null) return;
    state = AsyncData(EditorState(
      post: post,
      contents: current.contents,
      content: current.content,
      tab: current.tab,
      draftName: current.draftName,
      dirty: current.dirty,
    ));
  }
}

/// 文章编辑器提供者（family：文章 ID）。
final postEditorProvider = AsyncNotifierProvider.family<
    PostEditorNotifier, EditorState, int>(PostEditorNotifier.new);
