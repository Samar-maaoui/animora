// Carte de membre Animora — page statique.
// Les données sont dans le fragment de l'URL (#…), encodées en base64url :
// le navigateur ne l'envoie jamais au serveur qui héberge cette page.
(function () {
  'use strict';

  var MAX_TEXT = 80;

  function decodePayload(fragment) {
    var b64 = fragment.replace(/-/g, '+').replace(/_/g, '/');
    while (b64.length % 4) b64 += '=';
    var binary = atob(b64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  }

  function text(data, key, required) {
    var value = data[key];
    if (typeof value !== 'string' || value.length > MAX_TEXT ||
        (required && !value.trim())) {
      throw new Error('Champ invalide : ' + key);
    }
    return value.trim();
  }

  function isAllowedAvatar(url) {
    try {
      var u = new URL(url);
      return u.protocol === 'https:' && u.hostname === 'api.dicebear.com' &&
        url.length <= 300;
    } catch (e) {
      return false;
    }
  }

  function frDate(iso) {
    var p = iso.split('-');
    return p.length === 3 ? p[2] + '/' + p[1] + '/' + p[0] : iso;
  }

  // textContent uniquement : aucun HTML ne peut être injecté via le QR.
  function show(id, value) {
    document.getElementById(id).textContent = value;
  }

  function fail(message) {
    document.getElementById('card').hidden = true;
    document.getElementById('error').hidden = false;
    if (message) show('error-text', message);
    document.title = 'Carte de membre Animora — démonstration';
  }

  function render() {
    var fragment = window.location.hash.replace(/^#/, '');
    if (!fragment) {
      fail();
      return;
    }
    var data, card;
    try {
      data = decodePayload(fragment);
      if (!data || data.v !== 1) throw new Error('version');
      card = {
        first: text(data, 'f', true),
        last: text(data, 'l', false),
        profile: text(data, 'p', true),
        status: text(data, 's', true),
        number: text(data, 'n', true),
        joined: text(data, 'd', true),
        city: text(data, 'c', false)
      };
      if (!/^ANI-[0-9A-F]{8}$/.test(card.number) ||
          !/^\d{4}-\d{2}-\d{2}$/.test(card.joined)) {
        throw new Error('format');
      }
    } catch (e) {
      fail('Ce lien ne contient pas une carte Animora valide.');
      return;
    }
    var fullName = (card.first + ' ' + card.last).trim();
    show('name', fullName);
    show('profile', card.profile);
    show('status', card.status);
    show('number', card.number);
    show('joined', frDate(card.joined));
    show('city', card.city);
    document.getElementById('city-row').hidden = !card.city;
    show('initials', (card.first.charAt(0) || '') + (card.last.charAt(0) || ''));

    var avatar = document.getElementById('avatar');
    var initials = document.getElementById('initials');
    avatar.hidden = true;
    initials.hidden = false;
    if (typeof data.a === 'string' && isAllowedAvatar(data.a)) {
      avatar.onload = function () {
        avatar.hidden = false;
        initials.hidden = true;
      };
      avatar.alt = 'Avatar de ' + fullName;
      avatar.src = data.a;
    }
    document.getElementById('error').hidden = true;
    document.getElementById('card').hidden = false;
    document.title = 'Carte de ' + fullName + ' — Animora (démonstration)';
  }

  window.addEventListener('hashchange', render);
  render();
})();
