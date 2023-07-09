// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:checkmark/checkmark.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:on_audio_edit/on_audio_edit.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/edit_delete_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/strings.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/multi_artwork_container.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

import 'package:namida/main.dart';

Future<void> showEditTrackTagsDialog(Track track) async {
  if (!await requestManageStoragePermission()) {
    return;
  }

  final audioedit = OnAudioEdit();

  final info = await audioedit.readAudio(track.path);

  final RxBool trimWhiteSpaces = true.obs;
  final RxBool canEditTags = false.obs;
  final RxBool didAutoExtractFromFilename = false.obs;
  final RxString currentImagePath = ''.obs;

  final tagsControllers = <TagField, TextEditingController>{};
  final editedTags = <TagField, dynamic>{};

  // filling fields
  // TODO: fix [discNumber][trackTotal] (convert them to String)
  tagsControllers[TagField.title] = TextEditingController(text: info.title ?? '');
  tagsControllers[TagField.album] = TextEditingController(text: info.album ?? '');
  tagsControllers[TagField.artist] = TextEditingController(text: info.artist ?? '');
  tagsControllers[TagField.albumArtist] = TextEditingController(text: info.albumArtist ?? '');
  tagsControllers[TagField.genre] = TextEditingController(text: info.genre ?? '');
  tagsControllers[TagField.composer] = TextEditingController(text: info.composer ?? '');
  tagsControllers[TagField.comment] = TextEditingController(text: info.comment ?? '');
  tagsControllers[TagField.lyrics] = TextEditingController(text: info.lyrics ?? '');
  tagsControllers[TagField.trackNumber] = TextEditingController(text: info.track?.toString().toIf('', '0'));
  tagsControllers[TagField.discNumber] = TextEditingController(text: info.discNo?.toString().toIf('', '0'));
  tagsControllers[TagField.year] = TextEditingController(text: info.year?.toString().toIf('', '0'));
  tagsControllers[TagField.remixer] = TextEditingController(text: info.remixer);
  tagsControllers[TagField.trackTotal] = TextEditingController(text: info.trackTotal?.toString().toIf('', '0'));
  tagsControllers[TagField.discTotal] = TextEditingController(text: info.discTotal ?? '');
  tagsControllers[TagField.lyricist] = TextEditingController(text: info.lyricist ?? '');
  tagsControllers[TagField.language] = TextEditingController(text: info.language ?? '');
  tagsControllers[TagField.recordLabel] = TextEditingController(text: info.recordLabel ?? '');
  tagsControllers[TagField.country] = TextEditingController(text: info.country ?? '');

  Widget getTagTextField(TagField tag) {
    final changed1 = tag == TagField.title && editedTags[TagField.title] != info.title;
    final changed2 = tag == TagField.artist && editedTags[TagField.artist] != info.artist;
    return CustomTagTextField(
      controller: tagsControllers[tag]!,
      labelText: tag.toText(),
      hintText: tagsControllers[tag]!.text,
      icon: tag.toIcon(),
      didEditField: (didAutoExtractFromFilename.value && (changed1 || changed2)).obs,
      onChanged: (value) {
        editedTags[tag] = value;
        if (!canEditTags.value) {
          canEditTags.value = true;
        }
      },
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment ? 4 : null,
    );
  }

  NamidaNavigator.inst.navigateDialog(
    CustomBlurryDialog(
      scale: 0.94,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      normalTitleStyle: true,
      scrollable: false,
      icon: Broken.edit,
      title: Language.inst.EDIT_TAGS,
      trailingWidgets: [
        NamidaIconButton(
          icon: Broken.edit_2,
          onPressed: () {
            final subList = List<TagField>.from(TagField.values).obs;
            subList.removeWhere((element) => SettingsController.inst.tagFieldsToEdit.contains(element));

            NamidaNavigator.inst.navigateDialog(
              CustomBlurryDialog(
                scale: 0.94,
                title: Language.inst.TAG_FIELDS,
                child: SizedBox(
                  width: Get.width,
                  height: Get.height * 0.7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6.0),
                      Text('${Language.inst.ACTIVE} (${Language.inst.REORDERABLE})', style: Get.textTheme.displayMedium),
                      const SizedBox(height: 6.0),
                      Expanded(
                        child: Obx(
                          () {
                            final tagFields = SettingsController.inst.tagFieldsToEdit.toList();
                            return NamidaListView(
                              onReorder: (oldIndex, newIndex) {
                                if (newIndex > oldIndex) {
                                  newIndex -= 1;
                                }
                                final tfOld = tagFields[oldIndex];
                                SettingsController.inst.removeFromList(tagFieldsToEdit1: tfOld);
                                SettingsController.inst.insertInList(newIndex, tagFieldsToEdit1: tfOld);
                              },
                              itemBuilder: (context, i) {
                                final tf = tagFields[i];
                                return Padding(
                                  key: ValueKey(i.toString()),
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: ListTileWithCheckMark(
                                    active: true,
                                    title: tf.toText(),
                                    icon: tf.toIcon(),
                                    onTap: () {
                                      if (SettingsController.inst.tagFieldsToEdit.toList().length <= 3) {
                                        Get.snackbar(Language.inst.MINIMUM_ONE_FIELD, Language.inst.MINIMUM_ONE_FIELD_SUBTITLE);
                                        return;
                                      }
                                      SettingsController.inst.removeFromList(tagFieldsToEdit1: tf);
                                      subList.add(tf);
                                    },
                                  ),
                                );
                              },
                              itemCount: SettingsController.inst.tagFieldsToEdit.toList().length,
                              itemExtents: null,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(Language.inst.NON_ACTIVE, style: Get.textTheme.displayMedium),
                      const SizedBox(height: 6.0),
                      Expanded(
                        child: Obx(
                          () => NamidaListView(
                            itemBuilder: (context, i) {
                              final tf = subList[i];
                              return Padding(
                                key: ValueKey(i.toString()),
                                padding: const EdgeInsets.only(top: 8.0),
                                child: ListTileWithCheckMark(
                                  active: false,
                                  title: tf.toText(),
                                  icon: tf.toIcon(),
                                  onTap: () {
                                    SettingsController.inst.save(tagFieldsToEdit: [tf]);
                                    subList.remove(tf);
                                  },
                                ),
                              );
                            },
                            itemCount: subList.length,
                            itemExtents: null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        )
      ],
      leftAction: NamidaInkWell(
        bgColor: Get.theme.cardColor,
        onTap: () => trimWhiteSpaces.value = !trimWhiteSpaces.value,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => SizedBox(
                height: 18,
                width: 18,
                child: CheckMark(
                  strokeWidth: 2,
                  activeColor: Get.theme.listTileTheme.iconColor!,
                  inactiveColor: Get.theme.listTileTheme.iconColor!,
                  duration: const Duration(milliseconds: 400),
                  active: trimWhiteSpaces.value,
                ),
              ),
            ),
            const SizedBox(
              width: 8.0,
            ),
            Text(
              Language.inst.REMOVE_WHITESPACES,
              style: Get.textTheme.displaySmall,
            ),
          ],
        ),
      ),
      actions: [
        Obx(
          () => IgnorePointer(
            ignoring: !canEditTags.value,
            child: AnimatedOpacity(
              opacity: canEditTags.value ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (trimWhiteSpaces.value) {
                    editedTags.updateAll((key, value) => value.trim());
                  }

                  /// converting int-based empty fields to 0
                  /// this prevents crash resulted from assigning empty string to int.
                  /// TODO(MSOB7YY): fix, if the value is 0, it doesnt get updated
                  void fixEmptyInts(List<TagField> fields) {
                    fields.loop((field, index) {
                      if (editedTags[field] != null && editedTags[field] == '') {
                        editedTags[field] = 0;
                      }
                    });
                  }

                  fixEmptyInts([
                    TagField.trackNumber,
                    TagField.discNumber,
                    TagField.trackTotal,
                    TagField.discTotal,
                  ]);

                  final didUpdate = await editTrackMetadata(
                    track,
                    tags: {
                      if (editedTags.keyExists(TagField.title)) TagType.TITLE: editedTags[TagField.title],
                      if (editedTags.keyExists(TagField.album)) TagType.ALBUM: editedTags[TagField.album],
                      if (editedTags.keyExists(TagField.artist)) TagType.ARTIST: editedTags[TagField.artist],
                      if (editedTags.keyExists(TagField.albumArtist)) TagType.ALBUM_ARTIST: editedTags[TagField.albumArtist],
                      if (editedTags.keyExists(TagField.composer)) TagType.COMPOSER: editedTags[TagField.composer],
                      if (editedTags.keyExists(TagField.genre)) TagType.GENRE: editedTags[TagField.genre],
                      if (editedTags.keyExists(TagField.trackNumber)) TagType.TRACK: editedTags[TagField.trackNumber],
                      if (editedTags.keyExists(TagField.discNumber)) TagType.DISC_NO: editedTags[TagField.discNumber],
                      if (editedTags.keyExists(TagField.year)) TagType.YEAR: editedTags[TagField.year],
                      if (editedTags.keyExists(TagField.comment)) TagType.COMMENT: editedTags[TagField.comment],
                      if (editedTags.keyExists(TagField.lyrics)) TagType.LYRICS: editedTags[TagField.lyrics],
                      if (editedTags.keyExists(TagField.remixer)) TagType.REMIXER: editedTags[TagField.remixer],
                      if (editedTags.keyExists(TagField.trackTotal)) TagType.TRACK_TOTAL: editedTags[TagField.trackTotal],
                      if (editedTags.keyExists(TagField.discTotal)) TagType.DISC_TOTAL: editedTags[TagField.discTotal],
                      if (editedTags.keyExists(TagField.lyricist)) TagType.LYRICIST: editedTags[TagField.lyricist],
                      if (editedTags.keyExists(TagField.language)) TagType.LANGUAGE: editedTags[TagField.language],
                      if (editedTags.keyExists(TagField.recordLabel)) TagType.RECORD_LABEL: editedTags[TagField.recordLabel],
                      if (editedTags.keyExists(TagField.country)) TagType.COUNTRY: editedTags[TagField.country],
                    },
                    artworkPath: currentImagePath.value,
                  );
                  debugPrint(didUpdate.toString());

                  if (!didUpdate) {
                    Get.snackbar(Language.inst.METADATA_EDIT_FAILED, Language.inst.METADATA_EDIT_FAILED_SUBTITLE);
                  }

                  NamidaNavigator.inst.closeDialog();
                },
                icon: const Icon(Broken.pen_add),
                label: Text(Language.inst.SAVE),
              ),
            ),
          ),
        )
      ],
      child: Obx(
        () {
          SettingsController.inst.tagFieldsToEdit.toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: Get.height * 0.61,
                width: Get.width,
                child: ListView(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Obx(
                              () => ArtworkWidget(
                                track: track,
                                thumbnailSize: Get.width / 3,
                                bytes: currentImagePath.value != '' ? null : info.firstArtwork,
                                path: currentImagePath.value != '' ? currentImagePath.value : track.pathToImage,
                                onTopWidgets: [
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: NamidaBlurryContainer(
                                      onTap: () async {
                                        final pickedFile = await FilePicker.platform.pickFiles(type: FileType.image);
                                        final path = pickedFile?.files.first.path ?? '';
                                        if (pickedFile != null && path != '') {
                                          final copiedImage = await File(path).copy("${SettingsController.inst.defaultBackupLocation.value}/sussyimage.png");
                                          currentImagePath.value = copiedImage.path;
                                        }
                                      },
                                      borderRadius: BorderRadius.only(topLeft: Radius.circular(12.0.multipliedRadius)),
                                      child: const Icon(Broken.edit_2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          width: 12.0,
                        ),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...SettingsController.inst.tagFieldsToEdit.toList().take(2).map(
                                    (e) => Padding(
                                      padding: const EdgeInsets.only(top: 10.0),
                                      child: getTagTextField(e),
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    ...SettingsController.inst.tagFieldsToEdit.toList().sublist(2).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(top: 12.0),
                            child: getTagTextField(e),
                          ),
                        ),
                    const SizedBox(
                      height: 12.0,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 12.0,
              ),
              Text(
                track.path,
                style: Get.textTheme.displaySmall,
              ),
              const SizedBox(
                height: 4.0,
              ),
              Text(
                track.audioInfoFormatted,
                style: Get.textTheme.displaySmall,
              ),
              const SizedBox(height: 4.0),
              NamidaInkWell(
                borderRadius: 2.0,
                onTap: () {
                  final titleAndArtist = Indexer.inst.getTitleAndArtistFromFilename(track.path.getFilenameWOExt);
                  final title = titleAndArtist.$1;
                  final artist = titleAndArtist.$2;

                  if (tagsControllers[TagField.title]!.text != title || tagsControllers[TagField.artist]!.text != artist) {
                    tagsControllers[TagField.title]!.text = title;
                    tagsControllers[TagField.artist]!.text = artist;

                    editedTags[TagField.title] = title;
                    editedTags[TagField.artist] = artist;

                    canEditTags.value = true;
                  }
                  didAutoExtractFromFilename.value = true;
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Broken.magicpen, size: 14.0),
                    const SizedBox(width: 4.0),
                    Text(
                      "${Language.inst.AUTO_EXTRACT_TAGS_FROM_FILENAME} ${didAutoExtractFromFilename.value ? '✓' : ''}",
                      style: Get.textTheme.displaySmall?.copyWith(
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dashed,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

Future<void> editMultipleTracksTags(List<Track> tracksPre) async {
  if (!await requestManageStoragePermission()) {
    return;
  }
  RxList<Track> tracks = <Track>[].obs;
  tracks.assignAll(tracksPre);

  final toBeEditedTracksColumn = Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 12.0),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          Language.inst.MULTIPLE_TRACKS_TAGS_EDIT_NOTE,
          style: Get.textTheme.displayMedium,
        ),
      ),
      const SizedBox(height: 12.0),
      SizedBox(
        width: Get.width,
        height: Get.height / 2,
        child: ListView.builder(
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final tr = tracks[index];
            return Obx(
              () => TrackTile(
                index: index,
                track: tr,
                queueSource: QueueSource.allTracks,
                onTap: () => tracks.addIf(() => !tracks.contains(tr), tr),
                bgColor: tracks.contains(tr) ? null : Colors.black.withAlpha(0),
                trailingWidget: IconButton(
                  icon: const Icon(Broken.close_circle),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    tracks.remove(tr);
                  },
                ),
              ),
            );
          },
        ),
      ),
    ],
  );

  final RxBool trimWhiteSpaces = true.obs;
  final RxBool canEditTags = false.obs;
  final RxString currentImagePath = ''.obs;

  final tagsControllers = <TagField, TextEditingController>{};
  final editedTags = <TagField, dynamic>{};

  final availableTagsToEdit = <TagField>[
    TagField.album,
    TagField.artist,
    TagField.genre,
    TagField.year,
    TagField.comment,
    TagField.albumArtist,
    TagField.composer,
    TagField.trackTotal,
    TagField.discTotal,
  ];

  /// creating controllers
  availableTagsToEdit.loop((at, index) {
    tagsControllers[at] = TextEditingController();
  });
  Widget getTagTextField(TagField tag) {
    return CustomTagTextField(
      controller: tagsControllers[tag]!,
      labelText: tag.toText(),
      hintText: tagsControllers[tag]!.text,
      icon: tag.toIcon(),
      onChanged: (value) {
        editedTags[tag] = value;
        if (!canEditTags.value) {
          canEditTags.value = true;
        }
      },
      isNumeric: tag.isNumeric,
      maxLines: tag == TagField.comment ? 4 : null,
    );
  }

  NamidaNavigator.inst.navigateDialog(
    CustomBlurryDialog(
      scale: 0.94,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      normalTitleStyle: true,
      scrollable: false,
      icon: Broken.edit,
      title: Language.inst.EDIT_TAGS,
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            NamidaNavigator.inst.navigateDialog(
              CustomBlurryDialog(
                insetPadding: const EdgeInsets.all(42.0),
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0),
                isWarning: true,
                normalTitleStyle: true,
                actions: [
                  ElevatedButton(
                    onPressed: () => NamidaNavigator.inst.closeDialog(2),
                    child: Text(Language.inst.CANCEL),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (trimWhiteSpaces.value) {
                        editedTags.updateAll((key, value) => value.trim());
                      }

                      /// converting int-based empty fields to 0
                      /// this prevents crash resulted from assigning empty string to int.
                      /// TODO(MSOB7YY): fix, if the value is 0, it doesnt get updated
                      void fixEmptyInts(List<TagField> fields) {
                        fields.loop((field, index) {
                          if (editedTags[field] != null && editedTags[field] == '') {
                            editedTags[field] = 0;
                          }
                        });
                      }

                      fixEmptyInts([
                        TagField.trackTotal,
                        TagField.discTotal,
                      ]);

                      final RxInt successfullEdits = 0.obs;
                      final RxInt failedEdits = 0.obs;
                      final RxBool finishedEditing = false.obs;
                      final RxString updatingLibrary = '?'.obs;

                      NamidaNavigator.inst.navigateDialog(
                        Obx(
                          () => CustomBlurryDialog(
                            title: Language.inst.PROGRESS,
                            tapToDismiss: false,
                            normalTitleStyle: true,
                            actions: [
                              Obx(
                                () => AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: finishedEditing.value ? 1.0 : 0.5,
                                  child: IgnorePointer(
                                    ignoring: !finishedEditing.value,
                                    child: ElevatedButton(
                                      onPressed: () => NamidaNavigator.inst.closeDialog(2),
                                      child: Text(Language.inst.DONE),
                                    ),
                                  ),
                                ),
                              )
                            ],
                            bodyText:
                                '${Language.inst.SUCCEEDED}: ${successfullEdits.value}\n\n${Language.inst.FAILED}: ${failedEdits.value}\n\n${Language.inst.UPDATING} ${updatingLibrary.value}',
                          ),
                        ),
                      );
                      await tracks.loopFuture((tr, index) async {
                        final didUpdate = await editTrackMetadata(
                          tr,
                          tags: {
                            if (editedTags.keyExists(TagField.album)) TagType.ALBUM: editedTags[TagField.album],
                            if (editedTags.keyExists(TagField.artist)) TagType.ARTIST: editedTags[TagField.artist],
                            if (editedTags.keyExists(TagField.albumArtist)) TagType.ALBUM_ARTIST: editedTags[TagField.albumArtist],
                            if (editedTags.keyExists(TagField.composer)) TagType.COMPOSER: editedTags[TagField.composer],
                            if (editedTags.keyExists(TagField.genre)) TagType.GENRE: editedTags[TagField.genre],
                            if (editedTags.keyExists(TagField.year)) TagType.YEAR: editedTags[TagField.year],
                            if (editedTags.keyExists(TagField.comment)) TagType.COMMENT: editedTags[TagField.comment],
                            if (editedTags.keyExists(TagField.trackTotal)) TagType.TRACK_TOTAL: editedTags[TagField.trackTotal],
                            if (editedTags.keyExists(TagField.discTotal)) TagType.DISC_TOTAL: editedTags[TagField.discTotal],
                          },
                          artworkPath: currentImagePath.value,
                          updateTracks: false,
                        );
                        debugPrint(didUpdate.toString());
                        if (didUpdate) {
                          successfullEdits.value++;
                        } else {
                          failedEdits.value++;
                        }
                      });

                      updatingLibrary.value = '...';
                      if (failedEdits > 0) {
                        Get.snackbar('${Language.inst.METADATA_EDIT_FAILED} ($failedEdits)', Language.inst.METADATA_EDIT_FAILED_SUBTITLE);
                      }
                      await Indexer.inst.updateTracks(tracks, updateArtwork: currentImagePath.value != '');
                      // TODO: might need [EditDeleteController.inst.updateTrackPathInEveryPartOfNamida()] ?

                      updatingLibrary.value = '✓';
                      finishedEditing.value = true;
                    },
                    child: Text(Language.inst.CONFIRM),
                  ),
                ],
                child: toBeEditedTracksColumn,
              ),
            );
          },
          icon: const Icon(Broken.pen_add),
          label: Text(Language.inst.SAVE),
        )
      ],
      leftAction: NamidaInkWell(
        bgColor: Get.theme.cardColor,
        onTap: () => trimWhiteSpaces.value = !trimWhiteSpaces.value,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(
              () => SizedBox(
                height: 18,
                width: 18,
                child: CheckMark(
                  strokeWidth: 2,
                  activeColor: Get.theme.listTileTheme.iconColor!,
                  inactiveColor: Get.theme.listTileTheme.iconColor!,
                  duration: const Duration(milliseconds: 400),
                  active: trimWhiteSpaces.value,
                ),
              ),
            ),
            const SizedBox(
              width: 8.0,
            ),
            Text(
              Language.inst.REMOVE_WHITESPACES,
              style: Get.textTheme.displaySmall,
            ),
          ],
        ),
      ),
      child: Obx(
        () => tracks.isEmpty
            ? SizedBox(
                width: Get.width * 0.6,
                child: ElevatedButton(
                  onPressed: () {
                    NamidaNavigator.inst.navigateDialog(
                      CustomBlurryDialog(
                        insetPadding: const EdgeInsets.all(42.0),
                        contentPadding: EdgeInsets.zero,
                        child: toBeEditedTracksColumn,
                      ),
                    );
                  },
                  child: Obx(
                    () => Text(
                      tracks.displayTrackKeyword,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: Get.height * 0.7,
                    width: Get.width,
                    child: ListView(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                Obx(
                                  () => currentImagePath.value != ''
                                      ? ArtworkWidget(
                                          track: null,
                                          thumbnailSize: Get.width / 3,
                                          path: currentImagePath.value,
                                        )
                                      : MultiArtworkContainer(
                                          heroTag: 'edittags_artwork',
                                          size: Get.width / 3,
                                          tracks: tracks,
                                          onTopWidget: tracks.length > 3
                                              ? Positioned(
                                                  right: 0,
                                                  bottom: 0,
                                                  child: NamidaBlurryContainer(
                                                    width: Get.width / 6.2,
                                                    height: Get.width / 6.2,
                                                    borderRadius: BorderRadius.zero,
                                                    child: Center(
                                                      child: Text(
                                                        "+${tracks.length - 3}",
                                                        style: Get.textTheme.displayLarge,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                ),
                              ],
                            ),
                            const SizedBox(
                              width: 12.0,
                            ),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  const SizedBox(
                                    height: 8.0,
                                  ),
                                  SizedBox(
                                    width: Get.width,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        NamidaNavigator.inst.navigateDialog(
                                          CustomBlurryDialog(
                                            insetPadding: const EdgeInsets.all(42.0),
                                            contentPadding: EdgeInsets.zero,
                                            child: toBeEditedTracksColumn,
                                          ),
                                        );
                                      },
                                      child: Obx(
                                        () => Text(
                                          tracks.displayTrackKeyword,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 8.0,
                                  ),
                                  SizedBox(
                                    width: Get.width,
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        final pickedFile = await FilePicker.platform.pickFiles(type: FileType.image);
                                        final path = pickedFile?.files.first.path ?? '';
                                        if (pickedFile != null && path != '') {
                                          final copiedImage = await File(path).copy("${SettingsController.inst.defaultBackupLocation.value}/sussyimage.png");
                                          currentImagePath.value = copiedImage.path;
                                        }
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          Language.inst.EDIT_ARTWORK,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(
                          height: 12.0,
                        ),
                        const SizedBox(
                          height: 8.0,
                        ),
                        ...availableTagsToEdit.toList().map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(top: 10.0),
                                child: getTagTextField(e),
                              ),
                            ),
                        const SizedBox(
                          height: 12.0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 12.0,
                  ),
                  Obx(
                    () => Text(
                      [
                        tracks.displayTrackKeyword,
                        tracks.totalSizeFormatted,
                        tracks.totalDurationFormatted,
                      ].join(' • '),
                      style: Get.textTheme.displaySmall,
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class CustomTagTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? icon;
  final int hintMaxLines;
  final int? maxLines;
  final int? maxLength;
  final String? Function(String? value)? validator;
  final String labelText;
  final void Function(String value)? onChanged;
  final bool isNumeric;
  final TextInputType? keyboardType;
  final RxBool? didEditField;
  CustomTagTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.icon,
    this.hintMaxLines = 3,
    this.maxLines,
    this.maxLength,
    this.validator,
    this.onChanged,
    required this.labelText,
    this.isNumeric = false,
    this.keyboardType,
    this.didEditField,
  });
  final RxBool didChange = false.obs;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: null,
      child: TextFormField(
        validator: validator,
        maxLength: maxLength,
        controller: controller,
        textAlign: TextAlign.left,
        maxLines: maxLines,
        keyboardType: keyboardType ?? (isNumeric ? TextInputType.number : null),
        style: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, fontWeight: FontWeight.w600),
        onChanged: (value) {
          if (onChanged != null) onChanged!(value);
          if (!didChange.value) {
            didChange.value = true;
          }
        },
        decoration: InputDecoration(
          label: labelText != ''
              ? Obx(() {
                  final reallyChanged = (didChange.value || (didEditField?.value ?? false));
                  return Text('$labelText ${reallyChanged ? '(${Language.inst.CHANGED})' : ''}');
                })
              : null,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          hintMaxLines: hintMaxLines,
          contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          errorMaxLines: 3,
          suffixIcon: Icon(icon, size: 18.0),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.0.multipliedRadius),
            borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 2.0),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16.0.multipliedRadius),
            borderSide: BorderSide(color: Get.theme.colorScheme.onBackground.withAlpha(100), width: 1.0),
          ),
          hintText: hintText,
          hintStyle: context.textTheme.displaySmall?.copyWith(fontSize: 14.5.multipliedFontScale, color: context.textTheme.displaySmall?.color?.withAlpha(120)),
        ),
      ),
    );
  }
}

Future<bool> editTrackMetadata(
  Track track, {
  Map<TagType, dynamic>? tags,
  String insertComment = '',
  String artworkPath = '',
  bool updateTracks = true,
}) async {
  // i tried many other ways to automate this task, nothing worked
  // so yeah ask the user to select the specific folder
  // and provide an option in the setting to reset this premission
  await requestSAFpermission();

  final audioedit = OnAudioEdit();
  final info = await audioedit.readAudio(track.path);
  final copiedFile = kSdkVersion < 30 ? File(track.path) : await File(track.path).copy("${SettingsController.inst.defaultBackupLocation.value}/${track.filename}");
  if (insertComment != '') {
    final finalcomm = ((info.comment ?? '').isEmpty) ? insertComment : '$insertComment\n${info.comment}';
    await audioedit.editAudio(
      copiedFile.path,
      {TagType.COMMENT: finalcomm},
      searchInsideFolders: true,
    );
  }
  bool didUpdateTags = false;
  if (tags != null) {
    didUpdateTags = await audioedit.editAudio(
      copiedFile.path,
      tags,
      searchInsideFolders: true,
    );
  }

  final shoulUpdateArtwork = artworkPath != '';

  if (shoulUpdateArtwork) {
    try {
      await audioedit.editArtwork(
        copiedFile.path,
        imagePath: artworkPath,
        searchInsideFolders: true,
        description: artworkPath,
        openFilePicker: false,
      );
    } catch (e) {
      debugPrint(e.toString());
    }
  }
  if (kSdkVersion >= 30) {
    await copiedFile.copy(track.path);
    await copiedFile.delete();
  }

  if (updateTracks) {
    await Indexer.inst.updateTracks([track], updateArtwork: shoulUpdateArtwork);

    /// updating inside all namida after each track edit is not performant
    /// same effect could be achieved by just restarting namida.
    /// TODO(MSOB7YY): option to update everything OR restart.
    await EditDeleteController.inst.updateTrackPathInEveryPartOfNamida(track, track.path);
  }
  return didUpdateTags;
}

Future<void> requestSAFpermission() async {
  if (kSdkVersion < 30) {
    return;
  }
  final audioedit = OnAudioEdit();

  if (await audioedit.complexPermissionStatus()) {
    return;
  }

  await NamidaNavigator.inst.navigateDialog(
    CustomBlurryDialog(
      title: Language.inst.NOTE,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            Language.inst.CHOOSE_BACKUP_LOCATION_TO_EDIT_METADATA.replaceFirst('_BACKUP_LOCATION_', SettingsController.inst.defaultBackupLocation.value),
            style: Get.textTheme.displayMedium,
          ),
          const SizedBox(
            height: 16.0,
          ),
          Text(
            '${Language.inst.NOTE}:',
            style: Get.textTheme.displayMedium,
          ),
          const SizedBox(
            height: 4.0,
          ),
          Text(
            Language.inst.CHOOSE_BACKUP_LOCATION_TO_EDIT_METADATA_NOTE,
            style: Get.textTheme.displaySmall,
          ),
        ],
      ),
    ),
  );
  await audioedit.requestComplexPermission();
}
