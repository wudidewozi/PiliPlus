import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/member.dart';
import 'package:PiliPlus/models/common/member/archive_order_type_app.dart';
import 'package:PiliPlus/models/member/info.dart';
import 'package:PiliPlus/models_new/space/space_archive/data.dart';
import 'package:PiliPlus/models_new/space/space_archive/item.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:get/get.dart';

class HorizontalMemberPageController
    extends CommonListController<SpaceArchiveData, SpaceArchiveItem> {
  HorizontalMemberPageController({this.mid, required this.currAid});

  dynamic mid;

  final Rx<LoadingState<MemberInfoModel>> userState =
      LoadingState<MemberInfoModel>.loading().obs;
  final RxMap userStat = {}.obs;

  @override
  void onInit() {
    super.onInit();
    getUserInfo();
    queryData();
  }

  Future<void> getUserInfo() async {
    final res = await MemberHttp.memberInfo(mid: mid);
    userState.value = res;
    if (res.isSuccess) {
      getMemberStat();
      getMemberView();
    }
  }

  Future<void> getMemberStat() async {
    final res = await MemberHttp.memberStat(mid: mid);
    if (res case Success(:final response)) {
      userStat.addAll(response);
    }
  }

  Future<void> getMemberView() async {
    if (!Accounts.main.isLogin) {
      return;
    }
    final res = await MemberHttp.memberView(mid: mid);
    if (res case Success(:final response)) {
      userStat.addAll(response);
    }
  }

  @override
  bool customHandleResponse(bool isRefresh, Success response) {
    SpaceArchiveData data = response.response;
    count = data.count;
    if (isRefresh) {
      if (isLoadPrevious) {
        hasPrev = data.hasPrev ?? false;
      } else {
        hasNext = data.hasNext ?? false;
      }
    }
    if (isLoadPrevious) {
      if (loadingState.value case Success(:final response)) {
        (data.item ??= <SpaceArchiveItem>[]).addAll(response!);
      }
    } else if (!isRefresh) {
      if (loadingState.value case Success(:final response)) {
        (data.item ??= <SpaceArchiveItem>[]).insertAll(0, response!);
      }
    }
    firstAid = data.item?.firstOrNull?.param;
    lastAid = data.item?.lastOrNull?.param;
    loadingState.value = Success(data.item);
    isLoadPrevious = false;
    page++;
    return true;
  }

  String? currAid;
  String? firstAid;
  String? lastAid;
  ArchiveOrderTypeApp order = .pubdate;
  int? count;
  bool isLoadPrevious = false;
  bool hasPrev = true;
  bool hasNext = true;

  @override
  Future<LoadingState<SpaceArchiveData>> customGetData() async {
    final isLocating = page == 1;
    final res = await MemberHttp.spaceArchive(
      type: .video,
      mid: mid,
      aid: isLocating
          ? currAid
          : isLoadPrevious
          ? firstAid
          : lastAid,
      order: order,
      sort: !isLocating && isLoadPrevious ? .asc : null,
      pn: null,
      next: null,
      seasonId: null,
      seriesId: null,
      includeCursor: isLocating ? true : null,
    );
    if (isLocating && res is Success<SpaceArchiveData>) {
      await _fillNewer(res.response);
    }
    return res;
  }

  /// 以当前视频为锚点请求时, 接口只返回当前视频及其更早的投稿,
  /// 这里补一页更新的投稿拼到前面, 否则侧栏里永远看不到之后的视频
  Future<void> _fillNewer(SpaceArchiveData anchorPage) async {
    final anchorItems = anchorPage.item;
    if (anchorItems == null || anchorItems.isEmpty) {
      hasPrev = false;
      return;
    }
    final res = await MemberHttp.spaceArchive(
      type: .video,
      mid: mid,
      aid: currAid,
      order: order,
      sort: .asc,
    );
    if (res case Success<SpaceArchiveData>(:final response)) {
      final newer = response.item;
      hasPrev = newer != null && newer.isNotEmpty
          ? response.hasPrev ?? false
          : false;
      if (newer != null && newer.isNotEmpty) {
        anchorPage.item = [...newer, ...anchorItems];
      }
      return;
    }
    // 更新方向请求失败时, 保留接口返回的可上滑状态
    hasPrev = anchorPage.hasPrev ?? false;
  }

  @override
  Future<void> onRefresh() {
    assert(hasPrev);
    isLoadPrevious = true;
    return queryData();
  }

  @override
  Future<void> onReload() {
    firstAid = null;
    lastAid = null;
    hasNext = true;
    hasPrev = true;
    isEnd = false;
    page = 1;
    scrollController.jumpToTop();
    return super.onReload();
  }

  void queryBySort() {
    if (isLoading) return;
    order = order == .pubdate ? .click : .pubdate;
    onReload();
  }
}
