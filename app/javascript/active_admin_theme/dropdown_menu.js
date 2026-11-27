// Flowbite's dropdown shows and hides the list but sets no aria-expanded on the
// button and does not close on Escape. This adds both, and the arrow keys of
// a menu. Each dropdown is looked up through FlowbiteInstances, as tabs.js does.
const menus = () => [...document.querySelectorAll(".aat-dropdown-menu")]
const toggleOf = (menu) => document.getElementById(menu.getAttribute("aria-labelledby"))
const isOpen = (menu) => !menu.classList.contains("hidden")
const links = (menu) => [...menu.querySelectorAll("a[role=menuitem]")]
const close = (menu) => FlowbiteInstances.getInstance("Dropdown", menu.id)?.hide()

const sync = (menu) => toggleOf(menu)?.setAttribute("aria-expanded", String(isOpen(menu)))

const observer = new MutationObserver((records) => records.forEach((record) => sync(record.target)))
const watch = () => menus().forEach((menu) => {
  sync(menu)
  observer.observe(menu, {attributes: true, attributeFilter: ["class"]})
})

document.addEventListener("keydown", (event) => {
  const menu = menus().find((candidate) => isOpen(candidate) && (candidate.contains(event.target) || toggleOf(candidate) === event.target))
  if (event.key === "Escape") {
    menus().filter(isOpen).forEach((open) => {
      close(open)
      if (open === menu) toggleOf(open).focus()
    })
    return
  }
  const toggle = event.target.closest?.(".aat-dropdown-toggle")
  if (toggle && event.key === "ArrowDown") {
    event.preventDefault()
    const target = document.getElementById(toggle.getAttribute("aria-controls"))
    if (!isOpen(target)) toggle.click()
    links(target)[0]?.focus()
    return
  }
  if (!menu || !event.target.closest?.("a[role=menuitem]")) return
  const items = links(menu)
  const index = items.indexOf(event.target)
  const next = {ArrowDown: items[(index + 1) % items.length], ArrowUp: items[(index - 1 + items.length) % items.length],
    Home: items[0], End: items[items.length - 1]}[event.key]
  if (next) {
    event.preventDefault()
    next.focus()
  }
})

if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", watch)
else watch()
