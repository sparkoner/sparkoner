const state = { options: [], index: 0, busy: false, open: false };

const $ = (id) => document.getElementById(id);
const app = $('app');
const track = $('track');
const spawnButton = $('spawn');

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'apoc_camas';

function post(name, data) {
    return fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((res) => res.json()).catch(() => ({}));
}

function imagePath(name) {
    return `images/${name || 'refugio.png'}`;
}

function renderTrack() {
    track.innerHTML = '';
    state.options.forEach((opt, i) => {
        const card = document.createElement('div');
        card.className = 'card' + (i === state.index ? ' active' : '');
        const img = document.createElement('img');
        img.src = imagePath(opt.image);
        const name = document.createElement('div');
        name.className = 'name';
        name.textContent = opt.label;
        const kind = document.createElement('div');
        kind.className = 'kind';
        kind.textContent = opt.kindLabel;
        card.append(img, name, kind);
        card.addEventListener('click', () => select(i));
        track.appendChild(card);
    });
}

function renderDetail() {
    const opt = state.options[state.index];
    if (!opt) return;
    $('detail-image').src = imagePath(opt.image);
    const chip = $('detail-kind');
    chip.textContent = opt.kindLabel;
    chip.className = 'chip ' + opt.kind;
    $('detail-label').textContent = opt.label;
    $('detail-location').textContent = opt.location || '';
    $('detail-description').textContent = opt.description || '';
    $('counter').textContent = `${state.index + 1} / ${state.options.length}`;

    [...track.children].forEach((card, i) => card.classList.toggle('active', i === state.index));
    const active = track.children[state.index];
    if (active) active.scrollIntoView({ behavior: 'smooth', inline: 'center', block: 'nearest' });
}

function select(i) {
    if (!state.open || state.busy || state.options.length === 0) return;
    const count = state.options.length;
    state.index = ((i % count) + count) % count;
    renderDetail();
    post('select', { index: state.index + 1 });
}

function confirmSpawn() {
    if (!state.open || state.busy) return;
    state.busy = true;
    spawnButton.disabled = true;
    post('spawn', { index: state.index + 1 }).then((res) => {
        if (!res || !res.ok) {
            state.busy = false;
            spawnButton.disabled = false;
        }
    });
}

function open(data) {
    state.options = data.options || [];
    state.index = Math.max(0, (data.index || 1) - 1);
    state.busy = false;
    state.open = true;
    spawnButton.disabled = false;
    $('beds-count').innerHTML = `Camas colocadas: <strong>${data.beds || 0}</strong> / ${data.maxBeds || 0}`;
    renderTrack();
    renderDetail();
    app.classList.remove('hidden');
}

function close() {
    state.open = false;
    app.classList.add('hidden');
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') open(data);
    if (data.action === 'close') close();
});

document.addEventListener('keydown', (event) => {
    if (!state.open) return;
    const key = event.key.toLowerCase();
    if (key === 'arrowleft' || key === 'a') select(state.index - 1);
    else if (key === 'arrowright' || key === 'd') select(state.index + 1);
    else if (key === 'enter' || key === ' ') confirmSpawn();
});

$('prev').addEventListener('click', () => select(state.index - 1));
$('next').addEventListener('click', () => select(state.index + 1));
spawnButton.addEventListener('click', confirmSpawn);
