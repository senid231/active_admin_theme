// Upgrades selects to Tom Select: every filter and form select (unless the
// `all` setting is off), select[data-tom-select], and the AJAX selects of the
// `searchable_select` inputs (select[data-searchable-select-url]).
// data-tom-select="false" leaves a select native. The README has the details.
import TomSelect from "tom-select"

const config = {
  all: true,
  minChars: 3,
  texts: {
    any: "Any",
    noResults: "No results matched",
    typeToSearch: "Type %{count} chars to search...",
    loading: "Loading...",
    loadingMore: "Loading more...",
    noMoreResults: "No more results",
    selectParentFirst: "Select the parent first",
    add: "Add"
  }
}

// Settings and texts apply to selects upgraded after the call.
export const configure = (overrides = {}) => {
  const { texts, ...rest } = overrides
  Object.assign(config, rest)
  Object.assign(config.texts, texts)
}

const readPageConfig = () => {
  const element = document.getElementById("active-admin-theme-config")
  try {
    if (element) configure(JSON.parse(element.textContent).searchableSelect)
  } catch (error) {
    console.warn("searchable_select: invalid #active-admin-theme-config", error)
  }
  if (window.ActiveAdminTheme && window.ActiveAdminTheme.searchableSelect) configure(window.ActiveAdminTheme.searchableSelect)
}

const REMOTE = "select[data-searchable-select-url]"
const EXPLICIT = "select[data-tom-select]"
const PREDICATE = "select[data-search-methods]"
const BOOLEAN_FILTER = ".filters-form-field.boolean select"
const FILTER = ".filters-form-field.select select"
// Descendant combinator: a field with an error has div.field_with_errors
// between the li and the select.
const FORM = "form.formtastic li.input.select select"
const AUTO = [PREDICATE, BOOLEAN_FILTER, FILTER, FORM].join(", ")

const listening = new WeakSet()

const escapeHtml = (text) => String(text).replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`)
const message = (name, text) => `<div class="${name}">${escapeHtml(text)}</div>`

const hasBlank = (el) => Array.from(el.options).some((option) => option.value === "")

const ownSettings = (el) => {
  const raw = el.dataset.tomSelect
  if (!raw || raw === "true") return null
  try {
    const parsed = JSON.parse(raw)
    return parsed && typeof parsed === "object" ? parsed : null
  } catch (error) {
    console.warn("searchable_select: invalid JSON in data-tom-select", el, error)
    return null
  }
}

const merge = (settings, overrides) => {
  if (!overrides) return settings
  const { addPlugins, removePlugins, ...rest } = overrides
  let plugins = rest.plugins || settings.plugins || []
  if (Array.isArray(addPlugins)) plugins = [...new Set([...plugins, ...addPlugins])]
  if (Array.isArray(removePlugins)) plugins = plugins.filter((plugin) => !removePlugins.includes(plugin))
  return { ...settings, ...rest, plugins, render: { ...settings.render, ...rest.render } }
}

const baseSettings = (el) => {
  const inFilter = Boolean(el.closest(".filters-form-field"))
  const search = !el.matches(`${PREDICATE}, ${BOOLEAN_FILTER}`)
  const plugins = []
  if (search && !el.multiple) plugins.push("dropdown_input")
  if (el.multiple || (hasBlank(el) && !el.matches(PREDICATE))) plugins.push("remove_button")
  const settings = {
    plugins,
    maxOptions: null,
    selectOnTab: true,
    allowEmptyOption: false,
    render: {
      no_results: () => message("no-results", config.texts.noResults),
      option_create: (data, escape) => `<div class="create">${escapeHtml(config.texts.add)} <strong>${escape(data.input)}</strong>&hellip;</div>`
    }
  }
  if (!search) settings.controlInput = null
  const blank = Array.from(el.options).find((option) => option.value === "")
  if (!el.dataset.placeholder && !(blank && blank.textContent.trim()) && inFilter) settings.placeholder = config.texts.any
  return settings
}

const specsOf = (el) => {
  const raw = el.dataset.searchableSelectParents
  if (raw) {
    try {
      const list = JSON.parse(raw)
      if (Array.isArray(list)) return list
    } catch (error) {
      console.warn("searchable_select: invalid JSON in data-searchable-select-parents", el, error)
    }
  }
  const name = el.dataset.searchableSelectParentName
  return name ? [{ name, param: el.dataset.searchableSelectParentParam }] : []
}

// A multiple select is named `name[]`, and Rails adds a hidden input beside it
// and beside a checkbox, so a parent is every field of that name.
const parentsOf = (el) => {
  const fields = el.form ? Array.from(el.form.elements) : Array.from(document.querySelectorAll("select, input"))
  return specsOf(el).flatMap(({ name, param }) => {
    const own = fields.filter((field) => field.name === name || field.name === `${name}[]`)
    if (!own.length) console.warn(`searchable_select: parent input ${name} not found`, el)
    return own.length ? [{ param, fields: own }] : []
  })
}

const fieldValues = (field) => {
  if (field.type === "checkbox" || field.type === "radio") return field.checked ? [field.value] : []
  if (field.multiple) return Array.from(field.selectedOptions, (option) => option.value)
  return [field.value]
}

const isMultiple = ({ fields }) => fields.some((field) => field.multiple || field.name.endsWith("[]"))

// A lone checkbox is never empty: it sends true or false.
const valuesOf = (parent) => {
  const box = parent.fields.find((field) => field.type === "checkbox")
  if (box && !isMultiple(parent)) return [String(box.checked)]
  return parent.fields.flatMap(fieldValues).filter((value) => value !== "")
}

const stateOf = (parents) => JSON.stringify(parents.map(valuesOf))

const optional = (el) => "searchableSelectParentOptional" in el.dataset

const waiting = (el, parents) => !optional(el) && parents.some((parent) => !valuesOf(parent).length)

const pageUrl = (el, parents, query, page) => {
  const url = new URL(el.dataset.searchableSelectUrl, window.location.href)
  if (query.trim()) url.searchParams.set("term", query.trim())
  url.searchParams.set("page", String(page))
  if (el.dataset.searchableSelectPerPage) url.searchParams.set("per_page", el.dataset.searchableSelectPerPage)
  parents.forEach((parent) => {
    const values = valuesOf(parent)
    if (!parent.param || !values.length) return
    if (!isMultiple(parent)) {
      url.searchParams.set(parent.param, values[0])
      return
    }
    const param = parent.param.endsWith("[]") ? parent.param : `${parent.param}[]`
    values.forEach((value) => url.searchParams.append(param, value))
  })
  return url.toString()
}

const nextUrl = (href) => {
  const url = new URL(href)
  url.searchParams.set("page", String(Number(url.searchParams.get("page")) + 1))
  return url.toString()
}

const fetchPage = (href) =>
  fetch(href, { headers: { Accept: "application/json" }, credentials: "same-origin" })
    .then((response) => (response.ok ? response.json() : Promise.reject(response)))

// {results: [{id, text}], pagination: {more}}, or a bare array whose items may
// name the id `value`.
const resultsOf = (data) => {
  const list = Array.isArray(data) ? data : data.results || []
  return list.map((item) => (item.id === undefined && item.value !== undefined ? { ...item, id: item.value } : item))
}

const hasMore = (data) => Boolean(!Array.isArray(data) && data.pagination && data.pagination.more)

const remoteFields = { valueField: "id", labelField: "text", searchField: ["text"] }

// Every page of the endpoint up front; typing filters the loaded options.
const loadAllSettings = (el, parents) => {
  const fetchAll = (page, loaded) =>
    fetchPage(pageUrl(el, parents, "", page)).then((data) => {
      const results = loaded.concat(resultsOf(data))
      return hasMore(data) ? fetchAll(page + 1, results) : results
    })
  return {
    ...remoteFields,
    preload: !waiting(el, parents),
    shouldLoad: (query) => query === "",
    load(query, callback) {
      fetchAll(1, []).then((results) => {
        if (el.tomselect !== this) return
        callback(results)
        if ("searchableSelectAutoSelect" in el.dataset && results.length === 1 && !this.items.length) this.setValue(String(results[0].id))
      }).catch(() => callback())
    },
    render: { loading: () => message("loading", config.texts.loading) }
  }
}

const minCharsOf = (el) => {
  const own = el.dataset.searchableSelectMinChars
  return own === undefined || own === "" ? Number(config.minChars) : Number(own)
}

// One page per request; the dropdown shows the results of one query at a time.
const lazySettings = (el, parents) => {
  const minChars = minCharsOf(el)
  const state = { shown: null, pending: null, token: 0, ids: new Set() }
  el.searchableSelectState = state
  return {
    ...remoteFields,
    addPlugins: ["virtual_scroll"],
    preload: false,
    loadThrottle: 250,
    // The raw input length counts, so three spaces ask for the unfiltered list.
    shouldLoad: (query) => query.length >= minChars,
    // The server filters; a client-side text score would drop matches on other fields.
    score: (query) => (option) => (query.length >= minChars && state.ids.has(String(option.id)) ? 1 : 0),
    firstUrl: (query) => pageUrl(el, parents, query, 1),
    load(query, callback) {
      const href = this.getUrl(query)
      const first = new URL(href).searchParams.get("page") === "1"
      if (first) {
        state.token += 1
        state.pending = query
      }
      const token = state.token
      const settle = () => {
        this.loading = Math.max(this.loading - 1, 0)
        if (!this.loading) this.wrapper.classList.remove(this.settings.loadingClass)
      }
      fetchPage(href)
        .then((data) => {
          // rebuild() destroyed this instance, or a newer query was typed.
          if (el.tomselect !== this) return
          if (token !== state.token) return settle()
          if (hasMore(data)) this.setNextUrl(query, nextUrl(href))
          if (first) {
            state.ids = new Set()
            state.shown = query
            state.pending = null
            if (this.control_input.value === query) this.wrapper.classList.remove("searching")
          }
          const results = resultsOf(data)
          results.forEach((result) => state.ids.add(String(result.id)))
          // A late response must not reopen a dropdown the user already closed.
          const wasOpen = this.isOpen
          callback(results)
          if (!wasOpen && this.isOpen) this.close()
        })
        .catch(() => {
          if (el.tomselect !== this) return
          if (token !== state.token) return settle()
          state.pending = null
          this.wrapper.classList.remove("searching")
          callback()
        })
    },
    render: {
      not_loading: () => (minChars > 0 ? message("not-loading", config.texts.typeToSearch.replace("%{count}", minChars)) : null),
      loading: () => message("loading", config.texts.loading),
      loading_more: () => message("loading-more-results", config.texts.loadingMore),
      no_more_results: () => message("no-more-results", config.texts.noMoreResults)
    }
  }
}

// Tom Select trims the input and remembers the queries it served. A lazy
// select needs the raw input (three spaces), and the first page for every
// load that typing starts: only a scroll asks for the next page.
const patchLazy = (el, select) => {
  const state = el.searchableSelectState
  const minChars = minCharsOf(el)
  const input = select.control_input
  select.inputValue = () => input.value

  let scrolling = false
  const shouldLoadMore = select.settings.shouldLoadMore
  select.settings.shouldLoadMore = function () {
    scrolling = shouldLoadMore.call(this)
    // The plugin calls load() in the same turn, or not at all.
    setTimeout(() => { scrolling = false })
    return scrolling
  }
  const canLoad = select.canLoad.bind(select)
  select.canLoad = (query) => {
    if (!scrolling && query !== state.pending) {
      select.clearPagination()
      delete select.loadedSearches[query]
    }
    return canLoad(query)
  }

  // Set from the keystroke until the reply, which Tom Select's own `loading`
  // class is not: it waits for the refresh throttle.
  input.addEventListener("input", () => {
    select.wrapper.classList.toggle("searching", input.value.length >= minChars && input.value !== state.shown)
  })
  if (minChars === 0) {
    const browse = () => { if (input.value === "" && state.shown !== "" && state.pending !== "") select.load("") }
    select.on("focus", browse)
    select.on("dropdown_open", browse)
  }
}

const settingsFor = (el, parents) => {
  let settings = baseSettings(el)
  const remote = el.matches(REMOTE)
  const lazy = remote && !("searchableSelectLoadAll" in el.dataset)
  if (remote) settings = merge(settings, lazy ? lazySettings(el, parents) : loadAllSettings(el, parents))
  settings = merge(settings, ownSettings(el))
  if (waiting(el, parents)) settings.placeholder = el.dataset.searchableSelectParentPlaceholder || config.texts.selectParentFirst
  return { settings, lazy }
}

// Picking an option in a single select hands focus back to the control, and
// Tom Select then reopens the dropdown on its own. Ignore opens that follow a
// pick until the user presses the control again.
const closeAfterPick = (select) => {
  let picked = false
  const open = select.open.bind(select)
  select.open = () => { if (!picked) open() }
  select.on("item_add", () => { picked = true })
  select.control.addEventListener("mousedown", () => { picked = false }, true)
  select.wrapper.addEventListener("keydown", () => { picked = false }, true)
}

// Tom Select 2.6.2 keeps its refresh timer (refreshThrottle after a keystroke)
// when the dropdown closes or the focus leaves; the late refresh reopens the
// dropdown and takes the focus back. close(false) keeps the typed text.
const dropStaleRefresh = (select) => {
  select.on("dropdown_close blur", () => {
    if (select.control_input.value !== "") return
    clearTimeout(select.refreshTimeout)
    select.refreshTimeout = null
    select.wrapper.classList.remove("searching")
  })
}

const build = (el, parents) => {
  if (parents.length) el.dataset.searchableSelectParentValue = stateOf(parents)
  const { settings, lazy } = settingsFor(el, parents)
  const select = new TomSelect(el, settings)
  if (lazy) patchLazy(el, select)
  dropStaleRefresh(select)
  // Without a search input nothing shows the placeholder; the CSS prints this.
  if (!select.control_input.isConnected && select.settings.placeholder) select.control.dataset.placeholder = select.settings.placeholder
  if (!el.multiple) closeAfterPick(select)
  if (waiting(el, parents)) select.disable()
}

const rebuild = (el, parents) => {
  if (el.tomselect) el.tomselect.destroy()
  Array.from(el.options).forEach((option) => { if (option.value !== "") option.remove() })
  el.disabled = false
  // Lets selects that depend on this one reset too.
  el.dispatchEvent(new Event("change", { bubbles: true }))
  build(el, parents)
}

const wanted = (el) => {
  if (el.tomselect || el.classList.contains("ts-hidden-accessible") || el.closest("template")) return false
  if (el.dataset.tomSelect === "false") return false
  return el.matches(`${REMOTE}, ${EXPLICIT}`) || (config.all && el.matches(AUTO))
}

export const upgrade = (el) => {
  if (!wanted(el)) return
  const parents = parentsOf(el)
  build(el, parents)
  if (parents.length && !listening.has(el)) {
    listening.add(el)
    parents.forEach(({ fields }) => fields.forEach((field) => {
      field.addEventListener("change", () => {
        if (el.dataset.searchableSelectParentValue !== stateOf(parents)) rebuild(el, parents)
      })
    }))
  }
}

export const upgradeAll = (root = document) => {
  if (root.matches && root.matches("select")) upgrade(root)
  if (root.querySelectorAll) root.querySelectorAll("select").forEach(upgrade)
}

const start = () => {
  readPageConfig()
  upgradeAll(document)
  // Selects added later, such as has_many rows and dialogs.
  new MutationObserver((records) => {
    records.forEach((record) => {
      record.addedNodes.forEach((node) => { if (node.nodeType === 1) upgradeAll(node) })
    })
  }).observe(document.body, { childList: true, subtree: true })
}

if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start)
else start()
document.addEventListener("turbo:load", () => upgradeAll(document))
