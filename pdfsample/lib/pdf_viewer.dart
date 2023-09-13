// ignore_for_file: public_member_api_docs, sort_constructors_first, constant_identifier_names, non_constant_identifier_names, avoid_dynamic_calls, use_build_context_synchronously
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewer extends StatefulWidget {
  const PdfViewer({super.key});

  @override
  State<PdfViewer> createState() => _PdfViewerState();
}

// Types of input fields in PDF
enum PdfEditableFields { SIGNATURE, INPUTFIELD, CHECKBOX, PHONENO, NOTES, NAME }

class PDFInputFieldsMap {
  String name;
  int? index;
  PdfEditableFields inputType;
  Rect? position;
  String? value;
  bool isFilled;
  bool isMandatory() {
    return name.contains('*');
  }

  int? pageindex;
  PDFInputFieldsMap(
      {required this.name,
      this.index,
      this.isFilled = false,
      this.inputType = PdfEditableFields.INPUTFIELD,
      this.position,
      this.value});
}

class _PdfViewerState extends State<PdfViewer> {
  ValueNotifier<Uint8List?> drafted_documentBytes = ValueNotifier(null);
  List<PDFInputFieldsMap> allInputFields = [];
  final PdfViewerController _pdfViewerController = PdfViewerController();
  late PdfDocument document;
  late double heightPercentage;
  late double widthPercentage;
  Size? calculatedSize;
  bool kIsDesktop = kIsWeb || Platform.isMacOS || Platform.isWindows;
  late PdfFormFieldCollection? docFieldsCollection;
  late List<PDFInputFieldsMap> requiredFields;
  final FocusNode focusNode = FocusNode();
  static final GlobalKey _scaffoldKey = GlobalKey();
  bool isDialogShowing = false;
  @override
  void initState() {
    super.initState();
    requiredFields = [];
    drafted_documentBytes.value = null;
    getPdfBytes();
  }

  // /Get the PDF document as bytes.
  void getPdfBytes() async {
    Uint8List documentBytes =
        (await rootBundle.load('assets/cleaned_response.pdf'))
            .buffer
            .asUint8List();
    drafted_documentBytes.value = await markAnnotationFields(documentBytes);
  }

  @override
  void didChangeDependencies() {
    if (!isDialogShowing) {
      super.didChangeDependencies();
    }
  }

  @override
  void dispose() {
    drafted_documentBytes.value = null;
    requiredFields = [];
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));
    Size size = MediaQuery.of(context).size;
    var bottomSheet = Container(
      width: size.width,
      height: size.height * 0.1,
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(width: 0.5, color: Colors.grey.shade400),
          )),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: TextButton(child: const Text('Done'), onPressed: () async {}),
        ),
      ),
    );
    return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: false,
        bottomSheet: bottomSheet,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Container(
            color: Colors.white,
            width: size.width,
            child: Padding(
              padding: const EdgeInsets.only(left: 7),
              child: AppBar(
                title: const Text('Pdf Editing'),
              ),
            ),
          ),
        ),
        body: Focus(
            onKey: (node, event) => isDialogShowing
                ? KeyEventResult.skipRemainingHandlers
                : KeyEventResult.handled,
            canRequestFocus: false,
            child: ValueListenableBuilder<Uint8List?>(
              builder: (context, data, _) {
                // if (data != null) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 100),
                  child: drafted_documentBytes.value != null
                      ? SfPdfViewer.memory(
                          drafted_documentBytes.value!,
                          onFormFieldValueChanged: (details) {
                            if (details.formField is PdfTextFormField) {
                              PdfTextFormField ele =
                                  details.formField as PdfTextFormField;
                              if (ele.text.isEmpty) {
                                var editFiels = allInputFields.where(
                                    (inputlist) =>
                                        inputlist.name ==
                                        details.formField.name);
                                if (editFiels.isNotEmpty) {
                                  requiredFields.add(editFiels.first);
                                }

                                return;
                              }

                              for (PDFInputFieldsMap map in requiredFields) {
                                if (map.name == details.formField.name) {
                                  if (ele.text.isNotEmpty) {
                                    requiredFields.remove(map);
                                  }
                                  break;
                                }
                              }
                            }

                            if (details.formField is PdfSignatureFormField) {
                              PdfSignatureFormField ele =
                                  details.formField as PdfSignatureFormField;
                              if (details.newValue == null ||
                                  ele.signature!.isEmpty) {
                                var editFiels = allInputFields.where(
                                    (inputlist) =>
                                        inputlist.name ==
                                        details.formField.name);
                                if (editFiels.isNotEmpty) {
                                  requiredFields.add(editFiels.first);
                                }
                                return;
                              }
                              for (PDFInputFieldsMap map in requiredFields) {
                                if (map.name == details.formField.name) {
                                  if (ele.signature!.isNotEmpty) {
                                    requiredFields.remove(map);
                                  }
                                  break;
                                }
                              }
                            }
                          },
                          controller: _pdfViewerController,
                          canShowScrollHead: false,
                          initialScrollOffset:
                              _pdfViewerController.scrollOffset,
                          interactionMode: PdfInteractionMode.pan,
                        )
                      : const CircularProgressIndicator(),
                );
              },
              valueListenable: drafted_documentBytes,
            )));
  }

  /// Find the available input section from the PDF.
  Future<Uint8List?> markAnnotationFields(Uint8List data) async {
    requiredFields = [];
    document = PdfDocument(inputBytes: data.toList());
    PdfTextExtractor extractor = PdfTextExtractor(document);
    List<MatchedItem> findResult = extractor.findText([
      '[INT*]',
      '[INT]',
      '[SIGNATURE*]',
      '[SIGNATURE]',
      '[____________]',
      '[_________________]',
      '[________________*]',
      '[_____________________________]',
      '[____________________________*]',
      '[NAME                                        ]',
      '[_______________________________________]',
      '[_____________________________________________________________________]',
      '[X]'
    ]);
    if (findResult.isEmpty) {
      document.dispose();
      return null;
    } else {
      for (int i = 0; i < findResult.length; i++) {
        MatchedItem element = findResult[i];
        final page = document.pages[element.pageIndex];
        var eleName = "$i${element.text}";
        PDFInputFieldsMap map = PDFInputFieldsMap(name: eleName);
        map.index = i;
        map.position = element.bounds;
        map.value = '';
        map.pageindex = element.pageIndex;
        // Adding form field for signature
        if (element.text == '[SIGNATURE*]') {
          map.inputType = PdfEditableFields.SIGNATURE;
          document.form.fields
              .add(PdfSignatureField(page, eleName, bounds: element.bounds));
        }

        if (element.text == '[SIGNATURE]') {
          map.inputType = PdfEditableFields.SIGNATURE;
          document.form.fields
              .add(PdfSignatureField(page, eleName, bounds: element.bounds));
        }
        if (element.text == '[____________]' ||
            element.text == '[________________*]' ||
            element.text == '[_________________]') {
          map.inputType = PdfEditableFields.PHONENO;
          document.form.fields.add(PdfTextBoxField(
            page,
            eleName,

            //back color doesn't show for text fields
            backColor: PdfColor(255, 0, 255),
            //max length doesn't work
            maxLength: 5,
            element.bounds,
            text: '',
            font: PdfStandardFont(PdfFontFamily.helvetica, 10),
          ));
        }
        if (element.text == '[INT]' || element.text == '[INT*]') {
          map.inputType = PdfEditableFields.PHONENO;
          document.form.fields
              .add(PdfSignatureField(page, eleName, bounds: element.bounds));
        }
        if (element.text == '[NAME                                        ]' ||
            element.text == '[____________________________*]' ||
            element.text == '[_____________________________]') {
          map.inputType = PdfEditableFields.NAME;
          document.form.fields
              .add(PdfTextBoxField(page, eleName, element.bounds,

                  //back color doesn't show for text fields
                  backColor: PdfColor(255, 0, 255),
                  //max length doesn't work
                  maxLength: 5,
                  text: '',
                  font: PdfStandardFont(PdfFontFamily.helvetica, 10)));
        }
        if (element.text == '[X]') {
          map.inputType = PdfEditableFields.CHECKBOX;
          document.form.fields.add(PdfCheckBoxField(
              page, eleName, element.bounds,
              style: PdfCheckBoxStyle.check));
        }
        if (element.text ==
            '[_____________________________________________________________________]') {
          map.inputType = PdfEditableFields.NOTES;
          document.form.fields.add(PdfTextBoxField(
            page,
            eleName,
            element.bounds,

            //back color doesn't show for text fields
            backColor: PdfColor(255, 0, 255),
            //max length doesn't work
            maxLength: 5,
            text: '',
            font: PdfStandardFont(PdfFontFamily.helvetica, 10),
            isPassword: false,
            spellCheck: true,
          ));
        }
        if (element.text == '[_______________________________________]') {
          map.inputType = PdfEditableFields.NOTES;
          document.form.fields
              .add(PdfTextBoxField(page, eleName, element.bounds,
                  //back color doesn't show for text fields
                  backColor: PdfColor(255, 0, 255),

                  //max length doesn't work
                  maxLength: 5,
                  text: "",
                  font: PdfStandardFont(PdfFontFamily.helvetica, 10)));
        }
        if (element.text.contains('*')) {
          requiredFields.add(map);
          page.graphics.drawRectangle(
              bounds: element.bounds,
              pen: PdfPen.fromBrush(PdfBrushes.red, width: 3));
        }
        allInputFields.add(map);
      }
      return Uint8List.fromList(await document.save());
    }
  }
}
