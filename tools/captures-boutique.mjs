// Captures d'écran de l'application, en vraie taille de boutique.
//
// Produit deux jeux depuis l'application web servie en local :
//   docs/captures/telephone/  1290 × 2796  — App Store 6,7 pouces, Play Store téléphone
//   docs/captures/bureau/     2560 × 1600  — Play Store tablette, aperçus web
//
// Chaque jeu est décliné en thème clair et en thème sombre.
//
// Prérequis : la pile locale tourne (« make up » puis « make api »), et un compte de
// démonstration existe. Playwright n'est pas une dépendance du dépôt : il s'installe à
// la demande.
//
//   npm --prefix /tmp/pp-captures install playwright
//   NODE_PATH=/tmp/pp-captures/node_modules node tools/captures-boutique.mjs \
//     --email=... --motdepasse=... --evenement=<uuid>

import { chromium } from 'playwright';
import { mkdir } from 'node:fs/promises';
import path from 'node:path';

const argument = (nom, defaut) => {
  const trouve = process.argv.find((a) => a.startsWith(`--${nom}=`));
  return trouve ? trouve.slice(nom.length + 3) : defaut;
};

const BASE = argument('base', 'http://localhost:8080');
const EMAIL = argument('email', 'maxence.soiree@partyplan.local');
const MOTDEPASSE = argument('motdepasse', 'Soiree2026!Demo');
const EVENEMENT = argument('evenement', '');
const SORTIE = argument('sortie', 'docs/captures');

// Le canevas Flutter n'expose son arbre d'accessibilité qu'après ce clic : sans lui,
// aucun sélecteur de rôle ne trouve quoi que ce soit. Le clic doit être dépêché sur
// l'élément : Flutter place le repère hors écran, et un clic de pointeur ne l'atteint
// pas.
const ouvrirSemantique = (page) =>
  page.locator('flt-semantics-placeholder').dispatchEvent('click');

const respirer = (page, ms = 900) => page.waitForTimeout(ms);

// Le survol laisse une bulle d'aide au-dessus de la barre d'onglets, qui se retrouve
// sur la capture. La souris est renvoyée au centre avant chaque déclenchement.
async function capturer(page, dossier, nom) {
  await page.mouse.move(10, 10);
  await respirer(page, 500);
  const fichier = path.join(dossier, `${nom}.png`);
  await page.screenshot({ path: fichier });
  console.log('  ', fichier);
}

async function connecter(page) {
  await page.goto(`${BASE}/connexion`, { waitUntil: 'networkidle' });
  await ouvrirSemantique(page);
  await respirer(page, 1500);
  await page.getByRole('textbox', { name: 'prenom@exemple.fr' }).fill(EMAIL);
  await respirer(page, 600);
  // Le champ de mot de passe n'existe dans le document qu'une fois le premier champ
  // rempli : Flutter ne pose l'élément natif qu'au moment d'en avoir besoin.
  await page.locator('input[type="password"]').first().click({ force: true });
  await respirer(page, 400);
  await page.keyboard.type(MOTDEPASSE);
  await page.keyboard.press('Enter');
  await page.waitForFunction(() => !location.pathname.includes('connexion'), null, {
    timeout: 20000,
  });
  await respirer(page, 1800);
}

// Toute navigation par URL recharge la page : l'arbre d'accessibilité repart à zéro et
// doit être rouvert, sinon plus aucun sélecteur de rôle ne répond.
async function allerA(page, url, attente = 1600) {
  await page.goto(url, { waitUntil: 'networkidle' });
  await ouvrirSemantique(page);
  await respirer(page, attente);
}

async function ouvrirEvenement(page) {
  if (EVENEMENT) {
    await allerA(page, `${BASE}/events/${EVENEMENT}`);
    return EVENEMENT;
  }
  await page.getByRole('button', { name: /ORGANISATEUR|Le \d+/ }).first().click();
  await page.waitForFunction(() => location.pathname.startsWith('/events/'), null, {
    timeout: 15000,
  });
  await respirer(page, 1500);
  return page.evaluate(() => location.pathname.split('/')[2]);
}

// La navigation change de forme avec la largeur : barre d'onglets sur téléphone, rail
// latéral sur écran large. Le rail expose des boutons, pas des onglets.
async function onglet(page, nom) {
  const parRole = page.getByRole('tab', { name: nom }).first();
  const cible = (await parRole.count()) > 0
    ? parRole
    : page.getByRole('button', { name: nom }).first();
  await cible.click();
  await respirer(page, 1400);
}

async function jeu({ nom, viewport, deviceScaleFactor, colorScheme }) {
  const dossier = path.join(SORTIE, nom);
  await mkdir(dossier, { recursive: true });
  console.log(`\n== ${nom} — ${viewport.width}×${viewport.height} ×${deviceScaleFactor} ==`);

  const navigateur = await chromium.launch();
  const contexte = await navigateur.newContext({
    viewport,
    deviceScaleFactor,
    colorScheme,
    locale: 'fr-FR',
    timezoneId: 'Europe/Paris',
    reducedMotion: 'reduce',
  });
  const page = await contexte.newPage();

  // Écran de connexion, avant toute session.
  await allerA(page, `${BASE}/connexion`);
  await capturer(page, dossier, '00-connexion');

  await connecter(page);
  await capturer(page, dossier, '01-accueil');

  const id = await ouvrirEvenement(page);
  await capturer(page, dossier, '02-presences');

  await onglet(page, 'Courses');
  await capturer(page, dossier, '03-courses');

  await onglet(page, 'Dépenses');
  await capturer(page, dossier, '04-depenses');

  await page.getByRole('button', { name: 'Qui rend quoi' }).click();
  await respirer(page, 1400);
  await capturer(page, dossier, '05-remboursements');
  await page.goBack();
  await respirer(page, 1200);

  await onglet(page, 'Discussion');
  await capturer(page, dossier, '06-discussion');

  await allerA(page, `${BASE}/events/${id}/sondages`);
  await capturer(page, dossier, '07-sondage');

  await allerA(page, `${BASE}/events/${id}/inviter`);
  await capturer(page, dossier, '08-invitation');

  await navigateur.close();
}

// 430 × 932 en densité 3 donne 1290 × 2796 : la taille exacte demandée par l'App Store
// pour un iPhone 6,7 pouces, acceptée telle quelle par le Play Store.
const TELEPHONE = { width: 430, height: 932 };
// 1280 × 800 en densité 2 donne 2560 × 1600 : format tablette du Play Store.
const BUREAU = { width: 1280, height: 800 };

for (const variante of [
  { nom: 'telephone-clair', viewport: TELEPHONE, deviceScaleFactor: 3, colorScheme: 'light' },
  { nom: 'telephone-sombre', viewport: TELEPHONE, deviceScaleFactor: 3, colorScheme: 'dark' },
  { nom: 'bureau-clair', viewport: BUREAU, deviceScaleFactor: 2, colorScheme: 'light' },
  { nom: 'bureau-sombre', viewport: BUREAU, deviceScaleFactor: 2, colorScheme: 'dark' },
]) {
  await jeu(variante);
}

console.log('\nTerminé.');
