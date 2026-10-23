import $ from 'jquery';

document.addEventListener('DOMContentLoaded', () => {
  const modal = document.getElementById('auto-follow-account-search');
  const members = document.getElementById('auto-follow-members');
  const selectedAccounts = document.getElementById('auto-follow-selected-accounts');
  const searchForm = document.getElementById('auto-follow-search-form');
  const searchInput = document.getElementById('auto-follow-search-query');
  const searchResults = document.getElementById('auto-follow-search-results');
  const searchError = document.getElementById('auto-follow-search-error');
  const memberError = document.getElementById('auto-follow-member-error');
  const selectedAccountIds = new Set(
    Array.from((selectedAccounts || members)?.querySelectorAll('tr[data-account-id]') || [], (row) => row.dataset.accountId)
  );

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
    if (!response.ok) {
      let message = 'Request failed. Please try again.';
      try {
        message = (await response.json()).error || message;
      } catch {
        // Keep the generic message for non-JSON error responses.
      }
      throw new Error(message);
    }
    return response.status === 204 ? null : response.json();
  }

  function updateSearchButtons(accountId) {
    searchResults?.querySelectorAll('button[data-account-id]').forEach((button) => {
      if (button.dataset.accountId !== String(accountId)) return;

      const added = selectedAccountIds.has(String(accountId));
      button.disabled = added;
      button.textContent = added ? 'Added' : 'Add';
    });
  }

  function appendSelectedAccount(account) {
    document.getElementById('auto-follow-no-accounts')?.remove();
    const row = document.createElement('tr');
    row.dataset.accountId = String(account.id);

    const nameCell = document.createElement('td');
    nameCell.textContent = account.display_name || account.username;
    const hiddenId = document.createElement('input');
    hiddenId.type = 'hidden';
    hiddenId.name = 'auto_follow[account_ids][]';
    hiddenId.value = String(account.id);
    nameCell.append(hiddenId);

    const handleCell = document.createElement('td');
    handleCell.textContent = account.acct || [account.username, account.domain].filter(Boolean).join('@');
    const typeCell = document.createElement('td');
    typeCell.textContent = account.domain ? 'Remote' : 'Local';
    const actionCell = document.createElement('td');
    const removeButton = document.createElement('button');
    removeButton.type = 'button';
    removeButton.className = 'btn btn-sm btn-outline-danger';
    removeButton.dataset.removeStagedAccount = 'true';
    removeButton.title = 'Remove account';
    removeButton.setAttribute('aria-label', 'Remove account');
    removeButton.innerHTML = '<i class="fa-solid fa-trash"></i>';
    bindStagedAccountRemove(removeButton);
    actionCell.append(removeButton);

    row.append(nameCell, handleCell, typeCell, actionCell);
    selectedAccounts.append(row);
  }

  function bindStagedAccountRemove(button) {
    button.addEventListener('click', (event) => {
      event.preventDefault();
      const row = event.currentTarget.closest('tr');
      selectedAccountIds.delete(row.dataset.accountId);
      row.remove();
      if (!selectedAccounts.querySelector('tr[data-account-id]')) {
        const emptyRow = document.createElement('tr');
        emptyRow.id = 'auto-follow-no-accounts';
        emptyRow.innerHTML = '<td class="text-center info-box-content" colspan="4"><p class="text-muted small">No accounts added.</p></td>';
        selectedAccounts.append(emptyRow);
      }
      updateSearchButtons(row.dataset.accountId);
    });
  }

  selectedAccounts?.querySelectorAll('[data-remove-staged-account]').forEach(bindStagedAccountRemove);

  if (modal && searchForm) {
    searchInput.addEventListener('keydown', (event) => {
      if (event.key !== 'Enter' || event.isComposing) return;

      event.preventDefault();
    });

    searchInput.addEventListener('keyup', (event) => {
      if (event.key !== 'Enter' || event.isComposing || event.repeat || searchForm.querySelector('button').disabled) return;

      searchForm.requestSubmit();
    });

    searchForm.addEventListener('submit', async (event) => {
      event.preventDefault();
      searchError.textContent = '';
      searchResults.replaceChildren();
      const submit = searchForm.querySelector('button');
      submit.disabled = true;
      try {
        const url = new URL(modal.dataset.searchUrl, window.location.origin);
        url.searchParams.set('query', searchInput.value);
        const data = await request(url);
        if (!data.accounts.length) searchResults.textContent = 'No accounts found.';
        data.accounts.forEach((account) => {
          const row = document.createElement('div');
          row.className = 'd-flex align-items-center justify-content-between border-bottom py-2';
          if (account.avatar_url) {
            const avatar = document.createElement('img');
            avatar.src = account.avatar_url;
            avatar.alt = '';
            avatar.width = 48;
            avatar.height = 48;
            avatar.loading = 'lazy';
            avatar.className = 'rounded-circle mr-3 flex-shrink-0';
            row.append(avatar);
          }
          const label = document.createElement('span');
          label.className = 'text-break mr-2 flex-grow-1';
          label.textContent = `${account.display_name || account.username} (@${account.acct})`;
          const button = document.createElement('button');
          button.type = 'button';
          button.className = 'btn btn-sm btn-outline-secondary flex-shrink-0';
          button.dataset.accountId = String(account.id);
          button.textContent = selectedAccountIds.has(String(account.id)) ? 'Added' : 'Add';
          button.disabled = selectedAccountIds.has(String(account.id));
          button.addEventListener('click', async () => {
            button.disabled = true;
            try {
              if (modal.dataset.mode === 'form' || selectedAccounts) {
                if (!selectedAccounts) throw new Error('The account list is unavailable. Reload the form and try again.');

                appendSelectedAccount(account);
                selectedAccountIds.add(String(account.id));
                updateSearchButtons(account.id);
                $(modal).modal('hide');
                return;
              }

              if (!modal.dataset.addUrl) throw new Error('The account add endpoint is unavailable. Reload the page and try again.');

              await request(modal.dataset.addUrl, 'POST', { account_id: account.id });
              window.location.reload();
            } catch (error) {
              searchError.textContent = error.message;
              button.disabled = false;
            }
          });
          row.append(label, button);
          searchResults.append(row);
        });
      } catch (error) {
        searchError.textContent = error.message;
      } finally {
        submit.disabled = false;
      }
    });
  }

  members?.addEventListener('click', async (event) => {
    const button = event.target.closest('button');
    if (!button || button.disabled) return;
    const rows = Array.from(members.querySelectorAll('tr'));
    const row = button.closest('tr');
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