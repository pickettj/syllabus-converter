/* ===== COLLAPSIBLE SYLLABUS JAVASCRIPT =====
   Functions to handle expand/collapse functionality for hierarchical content

   REQUIRED HTML STRUCTURE:
   - .section-header + .section-content for main sections (## headings)
   - .subsection-header + .subsection-content for nested sections (### headings)
   - .toggle-icon elements within headers for visual feedback
   - onclick="toggleSection(this)" or onclick="toggleSubsection(this)" on headers
*/

/**
 * Toggles the visibility of a main section (## headings in markdown)
 */
function toggleSection(header) {
  const content = header.nextElementSibling;
  const icon = header.querySelector(".toggle-icon");

  if (content.classList.contains("active")) {
    content.classList.remove("active");
    header.classList.remove("active");
    icon.textContent = "▼";
  } else {
    content.classList.add("active");
    header.classList.add("active");
    icon.textContent = "▲";
  }
}

/**
 * Toggles the visibility of a subsection (### headings in markdown)
 */
function toggleSubsection(header) {
  const content = header.nextElementSibling;
  const icon = header.querySelector(".toggle-icon");

  if (content.classList.contains("active")) {
    content.classList.remove("active");
    header.classList.remove("active");
    icon.textContent = "▼";
  } else {
    content.classList.add("active");
    header.classList.add("active");
    icon.textContent = "▲";
  }
}

/**
 * Transform pandoc's standard HTML into collapsible structure
 * This function is called by the template after DOM is loaded
 */
function transformPandocToCollapsible() {
  console.log("Transform function called");
  const content = document.querySelector(".content");
  if (!content) {
    console.error("Content div not found");
    return;
  }

  console.log("Content found, children:", content.children.length);

  // Get all headings
  const headings = content.querySelectorAll("h1, h2, h3, h4, h5, h6");
  console.log("Headings found:", headings.length);

  const elements = Array.from(content.children);
  console.log("Total elements:", elements.length);

  // Group content by heading levels
  const sections = [];
  let currentSection = null;
  let currentSubsection = null;

  elements.forEach((element, index) => {
    const tagName = element.tagName.toLowerCase();
    const textContent = element.textContent || "";
    const preview =
      textContent.length > 50
        ? textContent.substring(0, 50) + "..."
        : textContent;
    console.log(`Element ${index}: ${tagName} - ${preview}`);

    if (tagName === "h1") {
      // H1 is the main title, skip it (already in header)
      element.style.display = "none";
      return;
    }

    if (tagName === "h2") {
      // Start new main section
      currentSection = {
        level: 2,
        title: element.textContent,
        element: element,
        content: [],
        subsections: [],
      };
      sections.push(currentSection);
      currentSubsection = null;
      console.log("Created section:", currentSection.title);
    } else if (tagName === "h3") {
      // Start new subsection
      if (currentSection) {
        currentSubsection = {
          level: 3,
          title: element.textContent,
          element: element,
          content: [],
        };
        currentSection.subsections.push(currentSubsection);
        console.log("Created subsection:", currentSubsection.title);
      }
    } else if (tagName === "h4" || tagName === "h5" || tagName === "h6") {
      // H4+ are content within sections/subsections
      if (currentSubsection) {
        currentSubsection.content.push(element);
      } else if (currentSection) {
        currentSection.content.push(element);
      }
    } else {
      // Regular content (p, ul, div, etc.)
      if (currentSubsection) {
        currentSubsection.content.push(element);
      } else if (currentSection) {
        currentSection.content.push(element);
      }
    }
  });

  console.log("Sections created:", sections.length);

  // Clear the content and rebuild with collapsible structure
  content.innerHTML = "";

  sections.forEach((section, index) => {
    console.log(`Building section ${index}: ${section.title}`);
    const sectionDiv = createCollapsibleSection(section);
    content.appendChild(sectionDiv);
  });

  console.log("Transformation complete");

  // Auto-expand first section if it exists
  const firstSection = document.querySelector(".section-header");
  if (firstSection) {
    toggleSection(firstSection);
  }

  // Run enhancement after transformation
  setTimeout(() => {
    enhanceContent();
  }, 100);
}

function createCollapsibleSection(section) {
  // Create main section wrapper
  const sectionDiv = document.createElement("div");
  sectionDiv.className = "section";

  // Create section header
  const headerDiv = document.createElement("div");
  headerDiv.className = "section-header";
  headerDiv.setAttribute("onclick", "toggleSection(this)");
  headerDiv.setAttribute("tabindex", "0");

  const titleSpan = document.createElement("span");
  titleSpan.textContent = section.title;

  const iconSpan = document.createElement("span");
  iconSpan.className = "toggle-icon";
  iconSpan.textContent = "▼";

  headerDiv.appendChild(titleSpan);
  headerDiv.appendChild(iconSpan);

  // Create section content wrapper
  const contentDiv = document.createElement("div");
  contentDiv.className = "section-content";

  const innerDiv = document.createElement("div");
  innerDiv.className = "section-inner";

  // Add direct content (not in subsections)
  section.content.forEach((element) => {
    innerDiv.appendChild(element);
  });

  // Add subsections
  section.subsections.forEach((subsection) => {
    const subsectionDiv = createCollapsibleSubsection(subsection);
    innerDiv.appendChild(subsectionDiv);
  });

  contentDiv.appendChild(innerDiv);
  sectionDiv.appendChild(headerDiv);
  sectionDiv.appendChild(contentDiv);

  return sectionDiv;
}

function createCollapsibleSubsection(subsection) {
  // Create subsection wrapper
  const subsectionDiv = document.createElement("div");
  subsectionDiv.className = "subsection";

  // Create subsection header
  const headerDiv = document.createElement("div");
  headerDiv.className = "subsection-header";
  headerDiv.setAttribute("onclick", "toggleSubsection(this)");
  headerDiv.setAttribute("tabindex", "0");

  const titleSpan = document.createElement("span");
  titleSpan.textContent = subsection.title;

  const iconSpan = document.createElement("span");
  iconSpan.className = "toggle-icon";
  iconSpan.textContent = "▼";

  headerDiv.appendChild(titleSpan);
  headerDiv.appendChild(iconSpan);

  // Create subsection content wrapper
  const contentDiv = document.createElement("div");
  contentDiv.className = "subsection-content";

  const innerDiv = document.createElement("div");
  innerDiv.className = "subsection-inner";

  // Add subsection content
  subsection.content.forEach((element) => {
    // Transform h4 elements into session blocks
    if (element.tagName.toLowerCase() === "h4") {
      const sessionDiv = document.createElement("div");
      sessionDiv.className = "session";

      const sessionTitle = document.createElement("h4");
      sessionTitle.textContent = element.textContent;
      sessionDiv.appendChild(sessionTitle);

      innerDiv.appendChild(sessionDiv);
    } else {
      // Check if this should be part of the last session
      const lastChild = innerDiv.lastElementChild;
      if (lastChild && lastChild.classList.contains("session")) {
        lastChild.appendChild(element);
      } else {
        innerDiv.appendChild(element);
      }
    }
  });

  contentDiv.appendChild(innerDiv);
  subsectionDiv.appendChild(headerDiv);
  subsectionDiv.appendChild(contentDiv);

  return subsectionDiv;
}

function enhanceContent() {
  console.log("Enhancing content...");
  const content = document.querySelector(".content");
  if (!content) return;

  // Add reading-list class to lists that follow "Reading:" or "Readings:"
  const strongElements = content.querySelectorAll("strong");

  strongElements.forEach((strong) => {
    const text = strong.textContent.toLowerCase();
    if (text.includes("reading") && text.includes(":")) {
      const nextElement = strong.parentElement.nextElementSibling;
      if (nextElement && nextElement.tagName.toLowerCase() === "ul") {
        const wrapper = document.createElement("div");
        wrapper.className = "reading-list";
        nextElement.parentNode.insertBefore(wrapper, nextElement);
        wrapper.appendChild(nextElement);
      }
    }
  });

  // Enhance deadline content
  const deadlineKeywords = ["deadline", "due date", "important dates"];
  content.querySelectorAll("h3, h4").forEach((heading) => {
    const text = heading.textContent.toLowerCase();
    if (deadlineKeywords.some((keyword) => text.includes(keyword))) {
      let nextElement = heading.nextElementSibling;
      while (nextElement && !nextElement.tagName.match(/^h[1-6]$/i)) {
        if (nextElement.tagName.toLowerCase() === "ul") {
          nextElement.classList.add("deadlines");
        }
        nextElement = nextElement.nextElementSibling;
      }
    }
  });
}

/**
 * Optional helper functions
 */
function collapseAllSections() {
  const allSections = document.querySelectorAll(".section-content.active");
  const allSubsections = document.querySelectorAll(
    ".subsection-content.active",
  );

  allSections.forEach((section) => {
    const header = section.previousElementSibling;
    toggleSection(header);
  });

  allSubsections.forEach((subsection) => {
    const header = subsection.previousElementSibling;
    toggleSubsection(header);
  });
}

function expandAllSections() {
  const allSections = document.querySelectorAll(
    ".section-content:not(.active)",
  );
  const allSubsections = document.querySelectorAll(
    ".subsection-content:not(.active)",
  );

  allSections.forEach((section) => {
    const header = section.previousElementSibling;
    toggleSection(header);
  });

  allSubsections.forEach((subsection) => {
    const header = subsection.previousElementSibling;
    toggleSubsection(header);
  });
}

/**
 * Initialize keyboard support
 */
document.addEventListener("DOMContentLoaded", function () {
  document.addEventListener("keydown", function (event) {
    const target = event.target;

    if (
      target.classList.contains("section-header") ||
      target.classList.contains("subsection-header")
    ) {
      if (
        event.key === "Enter" ||
        event.key === " " ||
        event.keyCode === 13 ||
        event.keyCode === 32
      ) {
        event.preventDefault();

        if (target.classList.contains("section-header")) {
          toggleSection(target);
        } else {
          toggleSubsection(target);
        }
      }
    }
  });
});
