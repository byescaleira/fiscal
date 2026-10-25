const toBuffer = (text) => {
  const base64 = text.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(text.length / 4) * 4, '=');
  return Uint8Array.from(atob(base64), (character) => character.charCodeAt(0)).buffer;
};

const toText = (buffer) => btoa(String.fromCharCode(...new Uint8Array(buffer))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

const ERRORS = {
  invalid_code: 'Código de configuração inválido ou expirado.',
  weak_password: 'A senha precisa ter pelo menos 14 caracteres.',
  mismatch: 'As senhas não conferem.',
  invalid_passkey: 'A passkey não foi aceita. Tente de novo.',
  invalid_credentials: 'Senha ou passkey inválida.',
  locked: 'Muitas tentativas. Tente de novo em 15 minutos.',
  expired: 'O pedido expirou. Tente de novo.',
  unsupported: 'Este navegador não oferece passkeys.',
  NotAllowedError: 'A passkey foi cancelada ou expirou.',
};

async function post(path, body) {
  const response = await fetch(path, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body), credentials: 'same-origin' });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(json.error ?? 'failed');
  return json;
}

function credentialJSON(credential) {
  const response = credential.response;
  const json = {
    id: credential.id,
    rawId: toText(credential.rawId),
    type: credential.type,
    clientExtensionResults: credential.getClientExtensionResults(),
    authenticatorAttachment: credential.authenticatorAttachment ?? undefined,
    response: { clientDataJSON: toText(response.clientDataJSON) },
  };
  if (response.attestationObject) {
    json.response.attestationObject = toText(response.attestationObject);
    json.response.transports = response.getTransports ? response.getTransports() : [];
  } else {
    json.response.authenticatorData = toText(response.authenticatorData);
    json.response.signature = toText(response.signature);
    if (response.userHandle) json.response.userHandle = toText(response.userHandle);
  }
  return json;
}

async function setup(form) {
  const data = new FormData(form);
  if (data.get('password') !== data.get('confirm')) throw new Error('mismatch');
  const { token, options } = await post('/admin/setup/start', { code: data.get('code'), password: data.get('password') });
  const publicKey = {
    ...options,
    challenge: toBuffer(options.challenge),
    user: { ...options.user, id: toBuffer(options.user.id) },
    excludeCredentials: (options.excludeCredentials ?? []).map((item) => ({ ...item, id: toBuffer(item.id) })),
  };
  const credential = await navigator.credentials.create({ publicKey });
  return post('/admin/setup/finish', { token, response: credentialJSON(credential) });
}

async function login(form) {
  const data = new FormData(form);
  const { token, options } = await post('/admin/login/start', {});
  const publicKey = {
    ...options,
    challenge: toBuffer(options.challenge),
    allowCredentials: (options.allowCredentials ?? []).map((item) => ({ ...item, id: toBuffer(item.id) })),
  };
  const credential = await navigator.credentials.get({ publicKey });
  return post('/admin/login/finish', { token, password: data.get('password'), response: credentialJSON(credential) });
}

for (const form of document.querySelectorAll('form[data-webauthn]')) {
  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    const error = form.querySelector('[data-error]');
    const button = form.querySelector('button[type="submit"]');
    error.hidden = true;
    button.disabled = true;
    try {
      if (!window.PublicKeyCredential) throw new Error('unsupported');
      const result = await (form.dataset.webauthn === 'setup' ? setup(form) : login(form));
      location.assign(result.redirect);
    } catch (failure) {
      error.textContent = ERRORS[failure.name] ?? ERRORS[failure.message] ?? 'Não deu certo. Tente de novo.';
      error.hidden = false;
      button.disabled = false;
    }
  });
}

for (const form of document.querySelectorAll('form[data-confirm]')) {
  form.addEventListener('submit', (event) => {
    if (!confirm(form.dataset.confirm)) event.preventDefault();
  });
}

for (const range of document.querySelectorAll('input[type="range"]')) {
  const output = document.querySelector(`output[for="${range.id}"]`);
  range.addEventListener('input', () => {
    output.textContent = `${range.value}%`;
  });
}
