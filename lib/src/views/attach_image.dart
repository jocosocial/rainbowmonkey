import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../logic/photo_manager.dart';
import '../widgets.dart';

class AttachImageButton extends StatelessWidget {
  const AttachImageButton({
    Key key,
    @required List<Uint8List> images,
    @required this.onUpdate,
    @required this.allowMultiple,
    this.enabled = true,
  }) : assert(onUpdate != null),
       assert(allowMultiple != null),
       assert(enabled != null),
       images = images == null ? const <Uint8List>[] : images,
       super(key: key);

  final List<Uint8List> images;

  final ValueSetter<List<Uint8List>> onUpdate;

  final bool allowMultiple;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        children: <Widget>[
          const Icon(Icons.add_photo_alternate),
          PositionedDirectional(
            bottom: 0.0,
            end: 0.0,
            child: images.isEmpty ? Container() : Container(
              decoration: ShapeDecoration(
                shape: const CircleBorder(),
                color: Theme.of(context).accentColor,
              ),
              padding: const EdgeInsets.all(4.0),
              child: Text('${images.length}', style: Theme.of(context).accentTextTheme.caption),
            ),
          ),
        ],
      ),
      tooltip: images.isEmpty ? 'Attach an image'
             : !allowMultiple ? 'Remove or replace the currently attached image'
             : images.length > 2 ? 'Attach another image or remove one of the attached images'
             : 'Attach another image or remove the attached image',
      onPressed: Cruise.of(context).isLoggedIn && enabled ? () {
        List<Uint8List> currentImages = images;
        showDialog<void>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Image attachments'),
              contentPadding: const EdgeInsets.fromLTRB(0.0, 20.0, 0.0, 0.0),
              content: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return AttachImageDialog(
                    images: currentImages,
                    onUpdate: (List<Uint8List> newImages) {
                      setState(() {
                        currentImages = newImages;
                        onUpdate(newImages);
                      });
                    },
                    allowMultiple: allowMultiple,
                  );
                },
              ),
              actions: <Widget>[
                FlatButton(
                  onPressed: () { Navigator.pop(context); },
                  child: const Text('CLOSE'),
                ),
              ],
            );
          }
        );
      } : null,
    );
  }
}

class AttachImageDialog extends StatelessWidget {
  const AttachImageDialog({
    Key key,
    this.oldImages,
    this.onUpdateOldImages,
    @required List<Uint8List> images,
    @required this.onUpdate,
    @required this.allowMultiple,
  }) : assert(onUpdate != null),
       assert(allowMultiple != null),
       assert(oldImages == null || onUpdateOldImages != null),
       images = images == null ? const <Uint8List>[] : images,
       super(key: key);

  final List<Photo> oldImages;

  final ValueSetter<List<Photo>> onUpdateOldImages;

  final List<Uint8List> images;

  final ValueSetter<List<Uint8List>> onUpdate;

  final bool allowMultiple;

  void _addImage(ImageSource source) async {
    final File file = await ImagePicker.pickImage(source: source);
    if (file != null)
      onUpdate(images.toList()..add(await file.readAsBytes()));
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> imageList = <Widget>[];
    if (oldImages != null) {
      for (int index = 0; index < oldImages.length; index += 1) {
        imageList.add(_SelectedImage(
          child: Image(image: Cruise.of(context).imageFor(oldImages[index], thumbnail: true)),
          onRemove: () {
            onUpdateOldImages(oldImages.toList()..removeAt(index));
          },
        ));
      }
    }
    for (int index = 0; index < images.length; index += 1) {
      imageList.add(_SelectedImage(
        child: Image.memory(images[index]),
        onRemove: () {
          onUpdate(images.toList()..removeAt(index));
        },
      ));
    }
    final bool canAdd = allowMultiple || (images.isEmpty && oldImages.isEmpty);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 48.0 * 2.0,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    tooltip: 'Add a photograph obtained from your camera.',
                    onPressed: canAdd ? () { _addImage(ImageSource.camera); } : null,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.image),
                    tooltip: 'Add a new image selected from the gallery.',
                    onPressed: canAdd ? () { _addImage(ImageSource.gallery); } : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: VSyncBuilder(
            builder: (BuildContext context, TickerProvider vsync) {
              return AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.fastOutSlowIn,
                vsync: vsync,
                child: SizedBox(
                  width: 500.0,
                  child: ListView(
                    children: imageList,
                    shrinkWrap: true,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SelectedImage extends StatelessWidget {
  const _SelectedImage({ Key key, this.child, this.onRemove }) : super(key: key);

  final Widget child;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        children: <Widget>[
          child,
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Container(
              decoration: const ShapeDecoration(
                shape: RoundedRectangleBorder(),
                color: Colors.white30,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete),
                tooltip: 'Remove this image.',
                onPressed: onRemove,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
