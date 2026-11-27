// Focus and validation for the confirm_dialog component. Flowbite's modal
// already opens, closes (Cancel, Escape, backdrop) and sets the dialog ARIA
// attributes; this adds what it lacks: focus into the dialog and back to the
// trigger, a Tab loop, a reset on close, and invalid-field marking. Listeners
// sit on document, so it works for dialogs rendered at any time.
// When a dialog opens it dispatches a bubbling "aat:confirm-dialog:open" event on
// the dialog, with detail { dialog, trigger }.
const FOCUSABLE = [
  "a[href]", "area[href]", "button:not([disabled])", "input:not([type=hidden]):not([disabled])",
  "select:not([disabled])", "textarea:not([disabled])", "summary", "iframe", "[contenteditable]:not([contenteditable=false])",
  "[tabindex]"
].map((selector) => `${selector}:not([tabindex^="-"])`).join(", ")
const openers = new WeakMap()

const reset = (dialog) => {
  dialog.querySelector("form").reset()
  dialog.querySelectorAll("input, select, textarea").forEach((field) => {
    field.setCustomValidity("")
    field.removeAttribute("aria-invalid")
  })
}

const watchClose = (dialog) => {
  const observer = new MutationObserver(() => {
    if (dialog.getAttribute("aria-hidden") !== "true") return
    observer.disconnect()
    reset(dialog)
    openers.get(dialog)?.focus()
  })
  observer.observe(dialog, { attributes: true, attributeFilter: ["aria-hidden"] })
}

document.addEventListener("click", (event) => {
  // The component's own button, or any element that opens the dialog by id.
  const trigger = event.target.closest("[data-modal-show], [data-modal-toggle]")
  const dialog = trigger && document.getElementById(trigger.dataset.modalShow || trigger.dataset.modalToggle)
  if (!dialog || !dialog.matches(".aat-confirm-modal")) return
  openers.set(dialog, trigger)
  watchClose(dialog)
  // Flowbite's own click listener on the trigger shows the dialog first; wait a tick so it is visible.
  setTimeout(() => {
    // Listeners may fill or add fields, so the event goes out before the focus moves.
    dialog.dispatchEvent(new CustomEvent("aat:confirm-dialog:open", { bubbles: true, detail: { dialog, trigger } }))
    const first = dialog.querySelector(".aat-confirm-body :is(input, select, textarea):not([type=hidden])") || dialog.querySelector(".aat-confirm-cancel")
    first.focus()
  })
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "Tab") return
  const dialog = event.target.closest?.(".aat-confirm-modal")
  if (!dialog) return
  const items = [...dialog.querySelectorAll(FOCUSABLE)].filter((el) => el.getClientRects().length)
  const first = items[0]
  const last = items[items.length - 1]
  if (event.shiftKey && (event.target === first || event.target === dialog)) {
    event.preventDefault()
    last.focus()
  } else if (!event.shiftKey && event.target === last) {
    event.preventDefault()
    first.focus()
  }
})

// The browser's own validation blocks the submit; these only mark the fields.
document.addEventListener("invalid", (event) => {
  if (event.target.closest(".aat-confirm-form")) event.target.setAttribute("aria-invalid", "true")
}, true)

document.addEventListener("input", (event) => {
  const field = event.target
  if (!field.closest?.(".aat-confirm-form")) return
  // A required text field must not pass on spaces alone.
  if (field.required && field.matches("input[type=text], textarea")) {
    field.setCustomValidity(field.value.trim() ? "" : field.dataset.blankMessage || "Required")
  }
  if (field.validity.valid) field.removeAttribute("aria-invalid")
})
