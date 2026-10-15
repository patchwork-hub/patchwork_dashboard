import $ from 'jquery';

document.addEventListener('DOMContentLoaded', () => {
  const modal = document.getElementById('starter-pack-account-search');
  if (!modal) return;

  const searchForm = document.getElementById('starter-pack-search-form');
  const searchInput = document.getElementById('starter-pack-search-query');
  const results = document.getElementById('starter-pack-search-results');
  const searchError = document.getElementById('starter-pack-search-error');
  const members = document.getElementById('starter-pack-members');
  const memberError = document.getElementById('starter-pack-member-error');
  const creatorField = document.getElementById('starter_pack_created_by_id');
  const assignedAccountIds = new Set(
    Array.from(members?.querySelectorAll('tr[data-account-id]') || [], (row) => row.dataset.accountId)
  );

  function updateAccountButton(button) {
    const isCreator = modal.dataset.mode === 'creator';
    const assigned = isCreator
      ? creatorField?.value === button.dataset.accountId
      : assignedAccountIds.has(button.dataset.accountId);
    button.disabled = assigned;
    button.textContent = isCreator ? (assigned ? 'Assigned' : 'Assign') : (assigned ? 'Added' : 'Add');
  }

  async function request(url, method = 'GET', data) {
    const response = await fetch(url, {
      method,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
      body: data ? JSON.stringify(data) : undefined,
    });
    if (!response.ok) throw new Error('Request failed. Please try again.');
    return response.status === 204 ? null : response.json();
  }

  const positionInput = document.getElementById('starter_pack_position');
  const instanceInput = document.getElementById('starter_pack_instance_name');
  if (positionInput?.dataset.previewUrl && instanceInput) {
    let manuallyEdited = false;
    let previewTimer;
    let previewVersion = 0;

    function refreshOrderPreview() {
      clearTimeout(previewTimer);
      const version = ++previewVersion;
      if (manuallyEdited) return;

      positionInput.value = '';
      previewTimer = setTimeout(async () => {
        try {
          const url = new URL(positionInput.dataset.previewUrl, window.location.origin);
          url.searchParams.set('instance_name', instanceInput.value);
          const data = await request(url);
          if (version === previewVersion && !manuallyEdited) positionInput.value = data.position;
        } catch {
          if (version === previewVersion && !manuallyEdited) positionInput.value = '';
        }
      }, 250);
    }

    instanceInput.addEventListener('input', refreshOrderPreview);
    positionInput.addEventListener('input', () => {
      manuallyEdited = positionInput.value !== '';
      refreshOrderPreview();
    });
  }

  searchInput.addEventListener('keydown', (event) => {
    if (event.key !== 'Enter' || event.isComposing) return;

    event.preventDefault();
    if (event.repeat || searchForm.querySelector('button').disabled) return;

    searchForm.requestSubmit();
  });

  searchForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    searchError.textContent = '';
    results.replaceChildren();
    const submit = searchForm.querySelector('button');
    submit.disabled = true;
    try {
      const url = new URL(modal.dataset.searchUrl, window.location.origin);
      url.searchParams.set('query', searchInput.value);
      const data = await request(url);
      if (!data.accounts.length) results.textContent = 'No accounts found.';
      data.accounts.forEach((account) => {
        const row = document.createElement('div');
        row.className = 'd-flex align-items-center justify-content-between border-bottom py-2';
        if (account.avatar_url) {
          const avatar = document.createElement('img');
          avatar.src = account.avatar_url;
          avatar.alt = '';
          avatar.width = 70;
          avatar.height = 70;
          avatar.loading = 'lazy';
          avatar.className = 'rounded-circle mr-3 flex-shrink-0';
          avatar.style.objectFit = 'cover';
          row.append(avatar);
        }
        const label = document.createElement('span');
        label.className = 'text-break mr-2 flex-grow-1';
        label.textContent = `${account.display_name || account.username} (@${account.acct})`;
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'btn btn-sm btn-outline-secondary flex-shrink-0';
        button.dataset.accountId = String(account.id);
        updateAccountButton(button);
        button.addEventListener('click', async () => {
          if (button.disabled) return;

          button.disabled = true;
          searchError.textContent = '';
          try {
            if (modal.dataset.mode === 'creator') {
              creatorField.value = account.id;
              document.getElementById('starter-pack-creator').textContent = label.textContent;
              results.querySelectorAll('button[data-account-id]').forEach(updateAccountButton);
              $(modal).modal('hide');
            } else {
              await request(modal.dataset.addUrl, 'POST', { account_id: account.id });
              assignedAccountIds.add(String(account.id));
              window.location.reload();
            }
          } catch (error) {
            searchError.textContent = error.message;
          } finally {
            updateAccountButton(button);
          }
        });
        row.append(label, button);
        results.append(row);
      });
    } catch (error) {
      searchError.textContent = error.message;
    } finally {
      submit.disabled = false;
    }
  });

  document.getElementById('starter-pack-clear-creator')?.addEventListener('click', () => {
    creatorField.value = '';
    document.getElementById('starter-pack-creator').textContent = 'Not assigned';
    results.querySelectorAll('button[data-account-id]').forEach(updateAccountButton);
  });

  members?.addEventListener('click', async (event) => {
    const button = event.target.closest('button');
    if (!button || button.disabled) return;
    const row = button.closest('tr');
    const rows = Array.from(members.querySelectorAll('tr'));
    memberError.textContent = '';
    members.querySelectorAll('button').forEach((control) => { control.disabled = true; });
    try {
      if (button.hasAttribute('data-remove')) {
        await request(members.dataset.removeUrl, 'DELETE', { account_id: row.dataset.accountId });
      } else {
        const index = rows.indexOf(row);
        const target = index + (button.dataset.move === 'up' ? -1 : 1);
        if (target < 0 || target >= rows.length) return;
        [rows[index], rows[target]] = [rows[target], rows[index]];
        await request(members.dataset.reorderUrl, 'PATCH', { ids: rows.map((entry) => entry.dataset.membershipId) });
      }
      window.location.reload();
    } catch (error) {
      memberError.textContent = error.message;
      rows.forEach((entry, index) => {
        entry.querySelectorAll('button').forEach((control) => { control.disabled = false; });
        entry.querySelector('[data-move="up"]').disabled = index === 0;
        entry.querySelector('[data-move="down"]').disabled = index === rows.length - 1;
      });
    }
  });
});