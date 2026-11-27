// Deep links for the tabs component. A URL hash naming a tab panel (or an
// element inside one) opens that tab on page load and on hashchange, and
// clicking a tab writes its panel id to the hash without a history entry.
// Flowbite builds its tab instances on window "load" (or on the host's own
// initFlowbite call under Turbo), so selecting waits for that and goes through
// the instance to keep aria-selected and the hidden classes in step.
const select = (panel) => {
  const button = document.querySelector(`.aat-tab[aria-controls="${CSS.escape(panel.id)}"]`)
  const tabs = button && FlowbiteInstances.getInstance("Tabs", button.closest("[data-tabs-toggle]").id)
  tabs?.show(button.dataset.tabsTarget)
}

const open = () => {
  const id = decodeURIComponent(location.hash.slice(1))
  const target = id && document.getElementById(id)
  if (!target) return
  const panels = []
  for (let panel = target.closest(".aat-tab-panel"); panel; panel = panel.parentElement?.closest(".aat-tab-panel")) {
    panels.unshift(panel)
  }
  const hidden = panels.filter((panel) => panel.classList.contains("hidden"))
  hidden.forEach(select)
  if (hidden.length && !target.matches(".aat-tab-panel")) target.scrollIntoView()
}

document.addEventListener("click", (event) => {
  const button = event.target.closest(".aat-tab[data-tabs-target]")
  if (button) history.replaceState(history.state, "", button.dataset.tabsTarget)
})

window.addEventListener("hashchange", open)
if (document.readyState === "complete") open()
else window.addEventListener("load", open)
document.addEventListener("turbo:load", () => setTimeout(open))
