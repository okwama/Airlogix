/**
 * Dispatch event on click outside of node
 */
export function clickOutside(node: HTMLElement, handler: () => void) {
  const handleClick = (event: MouseEvent) => {
    if (node && event.target instanceof Node && !node.contains(event.target) && !event.defaultPrevented) {
      handler();
    }
  };

  document.addEventListener('click', handleClick, true);

  return {
    destroy() {
      document.removeEventListener('click', handleClick, true);
    }
  };
}
