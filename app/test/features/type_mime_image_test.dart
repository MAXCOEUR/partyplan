import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/media/type_mime_image.dart';

void main() {
  group('typeMimeImage', () {
    test('reconnaît les formats acceptés par le serveur (RG-USR-01)', () {
      expect(typeMimeImage('photo.jpg'), 'image/jpeg');
      expect(typeMimeImage('photo.jpeg'), 'image/jpeg');
      expect(typeMimeImage('photo.png'), 'image/png');
      expect(typeMimeImage('photo.webp'), 'image/webp');
      expect(typeMimeImage('photo.heic'), 'image/heic');
      expect(typeMimeImage('photo.heif'), 'image/heif');
    });

    test('ignore la casse de l’extension', () {
      // Les appareils photo produisent couramment « IMG_0042.JPG ».
      expect(typeMimeImage('IMG_0042.JPG'), 'image/jpeg');
      expect(typeMimeImage('Photo.PnG'), 'image/png');
    });

    test('refuse un format que le serveur rejetterait', () {
      // Mieux vaut refuser tout de suite que téléverser pour rien.
      expect(typeMimeImage('animation.gif'), isNull);
      expect(typeMimeImage('scan.bmp'), isNull);
    });

    test('refuse un nom sans extension', () {
      expect(typeMimeImage('sansextension'), isNull);
      expect(typeMimeImage(''), isNull);
      expect(typeMimeImage('.jpg'), isNull);
    });

    test('ne retient que la dernière extension', () {
      // « photo.jpg.exe » n'est pas une image : un nom composé ne doit pas
      // suffire à faire passer un exécutable pour un JPEG.
      expect(typeMimeImage('photo.jpg.exe'), isNull);
      expect(typeMimeImage('mes.vacances.2026.png'), 'image/png');
    });

    test('tolère un chemin complet plutôt qu’un simple nom', () {
      // Le recadreur ne rend qu'un chemin : le nom doit s'en déduire.
      expect(
        typeMimeImage('/data/user/0/cache/recadre_1234.jpg'),
        'image/jpeg',
      );
      expect(typeMimeImage(r'C:\Users\max\Images\photo.png'), 'image/png');
    });
  });
}
