// Run only inside cua_repl. All website actions use the documented tab API.
export async function settleSave(tab) {
  const save = tab.playwright.getByRole('button', { name: 'Save', exact: true });
  await save.getByRole('progressbar').waitFor({ state: 'hidden', timeout: 20000 });
  if (await save.isEnabled()) {
    await save.press('Enter', { timeout: 15000 });
    await save.getByRole('progressbar').waitFor({ state: 'hidden', timeout: 20000 });
  }
  const state = await tab.playwright.domSnapshot();
  if (await save.isEnabled()) throw new Error('Connect has not saved the current changes. Inspect the page before continuing.');
  return state;
}

export async function selectLocale(tab, row, section = 'Product Page Information') {
  const state = await tab.playwright.domSnapshot();
  const buttons = [...(state.split(`heading "${section}"`)[1] ?? '').matchAll(/button "([^"]+)"/g)];
  const label = buttons[section === 'Privacy Policy' ? 1 : 0]?.[1];
  if (!label) throw new Error(`Missing locale control in ${section}`);
  if (label === row.displayName) return state;
  await tab.playwright.getByRole('button', { name: label, exact: true }).press('Enter', { timeout: 15000 });
  const menu = await tab.playwright.domSnapshot();
  const name = menu.includes(`menuitem "Add ${row.displayName}"`) ? `Add ${row.displayName}` : row.displayName;
  await tab.playwright.getByRole('menuitem', { name, exact: true }).press('Enter', { timeout: 15000 });
  const next = await tab.playwright.domSnapshot();
  if (!next.includes(`button "${row.displayName}"`)) throw new Error(`Locale selection failed: ${row.locale}`);
  return next;
}

export function fieldsFor(row, platform) {
  const fields = [
    ['Promotional Text', row.promotionalText],
    ['Description', row.description + (platform === 'tvOS' ? '' : '\n\n' + row.onlineNote)],
    ['Keywords', row.keywords],
    ['Support URL', 'https://nathanfennel.com/contact'],
  ];
  if (platform !== 'tvOS') fields.push(["What's New in This Version", row.whatsNew]);
  return fields;
}

export async function verifyFields(tab, row, platform) {
  for (const [label, value] of fieldsFor(row, platform)) {
    const matches = await tab.playwright.getByRole('textbox', { name: label, exact: true })
      .evaluate((element, expected) => element.value === expected, value, { timeout: 15000 });
    if (!matches) throw new Error(`${platform}/${row.locale}: ${label} differs from prepared copy`);
  }
  return { platform, locale: row.locale, fieldsMatch: true };
}

export async function putLocale(tab, row, platform) {
  await settleSave(tab);
  await selectLocale(tab, row);
  for (const [label, value] of fieldsFor(row, platform)) {
    await tab.playwright.getByRole('textbox', { name: label, exact: true }).fill(value, { timeout: 15000 });
  }
  await settleSave(tab);
  return verifyFields(tab, row, platform);
}

export async function putInfo(tab, row) {
  await selectLocale(tab, row, 'Localizable Information');
  await tab.playwright.getByRole('textbox', { name: 'Name', exact: true }).fill('Tally Tangle', { timeout: 15000 });
  await tab.playwright.getByRole('textbox', { name: 'Subtitle', exact: true }).fill(row.subtitle, { timeout: 15000 });
  const save = tab.playwright.getByRole('button', { name: 'Save', exact: true });
  if (await save.count() && await save.getAttribute('type') !== 'disabled') await save.press('Enter', { timeout: 15000 });
  await tab.playwright.getByRole('button', { name: /Saved$/ }).waitFor({ state: 'visible', timeout: 20000 });
  await tab.playwright.domSnapshot();
  const match = await tab.playwright.getByRole('textbox', { name: 'Subtitle', exact: true })
    .evaluate((element, expected) => element.value === expected, row.subtitle, { timeout: 15000 });
  if (!match) throw new Error(`Shared subtitle mismatch: ${row.locale}`);
  return { platform: 'sharedInfo', locale: row.locale, fieldsMatch: true };
}

export async function putPrivacy(tab, row) {
  await selectLocale(tab, row, 'Privacy Policy');
  await tab.playwright.getByRole('button', { name: 'Edit', exact: true }).first().press('Enter', { timeout: 15000 });
  const dialog = tab.playwright.getByRole('dialog', { name: 'Privacy Policy', exact: true });
  await dialog.waitFor({ state: 'visible', timeout: 15000 });
  await dialog.getByRole('textbox', { name: 'Privacy Policy URL Privacy Policy URL', exact: true })
    .fill('https://nathanfennel.com/race-to-dog-mountain/privacy.html', { timeout: 15000 });
  const text = `Tally Tangle — Apple TV\n\n${row.tvPrivacy}\n\nhttps://nathanfennel.com/race-to-dog-mountain/privacy.html\nhttps://nathanfennel.com/contact`;
  await dialog.getByRole('textbox', { name: 'Apple TV Privacy Policy Apple TV Privacy Policy', exact: true })
    .fill(text, { timeout: 15000 });
  await dialog.getByRole('button', { name: 'Save', exact: true }).press('Enter', { timeout: 15000 });
  await dialog.waitFor({ state: 'hidden', timeout: 20000 });
  const state = await tab.playwright.domSnapshot();
  if (!state.includes(row.tvPrivacy)) throw new Error(`Privacy copy mismatch: ${row.locale}`);
  return { platform: 'sharedPrivacy', locale: row.locale, fieldsMatch: true };
}
