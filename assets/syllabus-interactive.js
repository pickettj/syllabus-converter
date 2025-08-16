/* ===== COLLAPSIBLE SYLLABUS JAVASCRIPT =====
   Functions to handle expand/collapse functionality for hierarchical content

   UPDATED TO HANDLE 5-LEVEL HIERARCHY WITH INFINITE EXPANSION:
   - .section-header + .section-content for main sections (## headings)
   - .subsection-header + .subsection-content for nested sections (### headings)
   - .subsubsection-header + .subsubsection-content for deeper nesting (#### headings)
   - .session elements for individual content blocks (##### headings)
   - .toggle-icon elements within headers for visual feedback
*/

/**
 * Gets the actual scroll height of an element's content
 */
function getActualHeight(element) {
  // Temporarily show the element to measure its natural height
  const originalMaxHeight = element.style.maxHeight;
  const originalOverflow = element.style.overflow;
  
  element.style.maxHeight = 'none';
  element.style.overflow = 'visible';
  
  const height = element.scrollHeight;
  
  // Restore original styles
  element.style.maxHeight = originalMaxHeight;
  element.style.overflow = originalOverflow;
  
  return height;
}

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
    content.style.maxHeight = "0";
  } else {
    content.classList.add("active");
    header.classList.add("active");
    icon.textContent = "▲";
    
    // Calculate and set the actual required height
    const actualHeight = getActualHeight(content);
    content.style.maxHeight = actualHeight + "px";
    
    // After transition completes, set to auto for true infinite expansion
    setTimeout(() => {
      if (content.classList.contains("active")) {
        content.style.maxHeight = "none";
      }
    }, 500); // Match CSS transition duration
  }
}

/**
 * Toggles the visibility of a subsection (### headings in markdown)
 * When expanding, also expands all nested sub-subsections
 */
function toggleSubsection(header) {
  const content = header.nextElementSibling;
  const icon = header.querySelector(".toggle-icon");

  if (content.classList.contains("active")) {
    content.classList.remove("active");
    header.classList.remove("active");
    icon.textContent = "▼";
    content.style.maxHeight = "0";
  } else {
    content.classList.add("active");
    header.classList.add("active");
    icon.textContent = "▲";

    // Auto-expand all nested sub-subsections when expanding a subsection
    const nestedSubSubsections = content.querySelectorAll(
      ".subsubsection-header:not(.active)",
    );
    nestedSubSubsections.forEach((subHeader) => {
      const subContent = subHeader.nextElementSibling;
      const subIcon = subHeader.querySelector(".toggle-icon");

      subContent.classList.add("active");
      subHeader.classList.add("active");
      subIcon.textContent = "▲";
      
      // Set height for nested sub-subsections
      const subActualHeight = getActualHeight(subContent);
      subContent.style.maxHeight = subActualHeight + "px";
      
      setTimeout(() => {
        if (subContent.classList.contains("active")) {
          subContent.style.maxHeight = "none";
        }
      }, 400);
    });
    
    // Calculate and set the actual required height for the subsection
    // Wait a moment for nested elements to expand first
    setTimeout(() => {
      const actualHeight = getActualHeight(content);
      content.style.maxHeight = actualHeight + "px";
      
      setTimeout(() => {
        if (content.classList.contains("active")) {
          content.style.maxHeight = "none";
        }
      }, 500);
    }, 50);
  }
}

/**
 * Toggles the visibility of a sub-subsection (#### headings in markdown)
 */
function toggleSubSubsection(header) {
  const content = header.nextElementSibling;
  const icon = header.querySelector(".toggle-icon");

  if (content.classList.contains("active")) {
    content.classList.remove("active");
    header.classList.remove("active");
    icon.textContent = "▼";
    content.style.maxHeight = "0";
  } else {
    content.classList.add("active");
    header.classList.add("active");
    icon.textContent = "▲";
    
    // Calculate and set the actual required height
    const actualHeight = getActualHeight(content);
    content.style.maxHeight = actualHeight + "px";
    
    // After transition completes, set to auto for true infinite expansion
    setTimeout(() => {
      if (content.classList.contains("active")) {
        content.style.maxHeight = "none";
      }
    }, 400);
  }
  
  // Update parent heights if needed
  updateParentHeights(header);
}

/**
 * Updates parent container heights when nested content changes
 */
function updateParentHeights(element) {
  let parent = element.closest('.subsection-content, .section-content');
  
  while (parent && parent.classList.contains('active')) {
    if (parent.style.maxHeight !== "none") {
      const actualHeight = getActualHeight(parent);
      parent.style.maxHeight = actualHeight + "px";
      
      // Set to auto after a brief delay
      setTimeout(() => {
        if (parent.classList.contains("active")) {
          parent.style.maxHeight = "none";
        }
      }, 100);
    }
    
    // Move to next parent level
    const parentHeader = parent.previousElementSibling;
    if (parentHeader) {
      parent = parentHeader.closest('.subsection-content, .section-content');
    } else {
      break;
    }
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
  let currentSubSubsection = null;

  elements.forEach((element, index) => {
    const tagName = element.tagName.toLowerCase();
    const textContent = element.textContent || "";
    const preview =
      textContent.length > 50
        ? textContent.substring(0, 50) + "..."
        : textContent;
    console.log(`Element ${index}: ${tagName} - ${preview}`);

    if (tagName === "h1") {
      // Use H1 for page title and header
      document.title = element.textContent;
      const header = document.querySelector("header h1");
      if (header) {
        header.textContent = element.textContent;
      } else {
        // Create title if header doesn't have one
        const headerTitle = document.createElement("h1");
        headerTitle.textContent = element.textContent;
        document.querySelector("header").appendChild(headerTitle);
      }
      element.style.display = "none";
      return;
    }

    // Skip processing the last-updated wrapper - leave it as is
    if (element.classList && element.classList.contains("last-updated-wrapper")) {
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
      currentSubSubsection = null;
      console.log("Created section:", currentSection.title);
    } else if (tagName === "h3") {
      // Start new subsection
      if (currentSection) {
        currentSubsection = {
          level: 3,
          title: element.textContent,
          element: element,
          content: [],
          subsubsections: [],
        };
        currentSection.subsections.push(currentSubsection);
        currentSubSubsection = null;
        console.log("Created subsection:", currentSubsection.title);
      }
    } else if (tagName === "h4") {
      // Start new sub-subsection
      if (currentSubsection) {
        currentSubSubsection = {
          level: 4,
          title: element.textContent,
          element: element,
          content: [],
          sessions: [],
        };
        currentSubsection.subsubsections.push(currentSubSubsection);
        console.log("Created sub-subsection:", currentSubSubsection.title);
      } else if (currentSection) {
        // If no subsection, add directly to section
        currentSubSubsection = {
          level: 4,
          title: element.textContent,
          element: element,
          content: [],
          sessions: [],
        };
        currentSection.content.push(currentSubSubsection);
        console.log(
          "Created sub-subsection in section:",
          currentSubSubsection.title,
        );
      }
    } else if (tagName === "h5") {
      // H5 becomes a session within current sub-subsection
      if (currentSubSubsection) {
        const session = {
          level: 5,
          title: element.textContent,
          element: element,
          content: [],
        };
        currentSubSubsection.sessions.push(session);
        console.log("Created session:", session.title);
      }
    } else if (tagName === "h6") {
      // H6+ are content within sessions or sub-subsections
      if (currentSubSubsection && currentSubSubsection.sessions.length > 0) {
        const lastSession =
          currentSubSubsection.sessions[
            currentSubSubsection.sessions.length - 1
          ];
        lastSession.content.push(element);
      } else if (currentSubSubsection) {
        currentSubSubsection.content.push(element);
      } else if (currentSubsection) {
        currentSubsection.content.push(element);
      } else if (currentSection) {
        currentSection.content.push(element);
      }
    } else {
      // Regular content (p, ul, div, etc.)
      if (currentSubSubsection && currentSubSubsection.sessions.length > 0) {
        const lastSession =
          currentSubSubsection.sessions[
            currentSubSubsection.sessions.length - 1
          ];
        lastSession.content.push(element);
      } else if (currentSubSubsection) {
        currentSubSubsection.content.push(element);
      } else if (currentSubsection) {
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

  // Auto-expand all main sections (## headings) by default
  const allSectionHeaders = document.querySelectorAll(".section-header");
  allSectionHeaders.forEach(header => {
    toggleSection(header);
  });

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
  contentDiv.style.maxHeight = "0"; // Start collapsed

  const innerDiv = document.createElement("div");
  innerDiv.className = "section-inner";

  // Add direct content (not in subsections)
  section.content.forEach((element) => {
    if (element.level === 4) {
      // This is a sub-subsection that was added directly to section
      const subSubsectionDiv = createCollapsibleSubSubsection(element);
      innerDiv.appendChild(subSubsectionDiv);
    } else {
      innerDiv.appendChild(element);
    }
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
  contentDiv.style.maxHeight = "0"; // Start collapsed

  const innerDiv = document.createElement("div");
  innerDiv.className = "subsection-inner";

  // Add direct content (not in sub-subsections)
  subsection.content.forEach((element) => {
    innerDiv.appendChild(element);
  });

  // Add sub-subsections
  subsection.subsubsections.forEach((subsubsection) => {
    const subSubsectionDiv = createCollapsibleSubSubsection(subsubsection);
    innerDiv.appendChild(subSubsectionDiv);
  });

  contentDiv.appendChild(innerDiv);
  subsectionDiv.appendChild(headerDiv);
  subsectionDiv.appendChild(contentDiv);

  return subsectionDiv;
}

function createCollapsibleSubSubsection(subsubsection) {
  // Create sub-subsection wrapper
  const subSubsectionDiv = document.createElement("div");
  subSubsectionDiv.className = "subsubsection";

  // Create sub-subsection header
  const headerDiv = document.createElement("div");
  headerDiv.className = "subsubsection-header";
  headerDiv.setAttribute("onclick", "toggleSubSubsection(this)");
  headerDiv.setAttribute("tabindex", "0");

  const titleSpan = document.createElement("span");
  titleSpan.textContent = subsubsection.title;

  const iconSpan = document.createElement("span");
  iconSpan.className = "toggle-icon";
  iconSpan.textContent = "▼";

  headerDiv.appendChild(titleSpan);
  headerDiv.appendChild(iconSpan);

  // Create sub-subsection content wrapper
  const contentDiv = document.createElement("div");
  contentDiv.className = "subsubsection-content";
  contentDiv.style.maxHeight = "0"; // Start collapsed

  const innerDiv = document.createElement("div");
  innerDiv.className = "subsubsection-inner";

  // Add direct content (not in sessions)
  subsubsection.content.forEach((element) => {
    innerDiv.appendChild(element);
  });

  // Add sessions (H5 content)
  subsubsection.sessions.forEach((session) => {
    const sessionDiv = document.createElement("div");
    sessionDiv.className = "session";

    const sessionTitle = document.createElement("h5");
    sessionTitle.textContent = session.title;
    sessionDiv.appendChild(sessionTitle);

    // Add session content
    session.content.forEach((element) => {
      sessionDiv.appendChild(element);
    });

    innerDiv.appendChild(sessionDiv);
  });

  contentDiv.appendChild(innerDiv);
  subSubsectionDiv.appendChild(headerDiv);
  subSubsectionDiv.appendChild(contentDiv);

  return subSubsectionDiv;
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
  content.querySelectorAll("h3, h4, h5").forEach((heading) => {
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
  const allSubSubsections = document.querySelectorAll(
    ".subsubsection-content.active",
  );

  allSections.forEach((section) => {
    const header = section.previousElementSibling;
    toggleSection(header);
  });

  allSubsections.forEach((subsection) => {
    const header = subsection.previousElementSibling;
    toggleSubsection(header);
  });

  allSubSubsections.forEach((subsubsection) => {
    const header = subsubsection.previousElementSibling;
    toggleSubSubsection(header);
  });
}

function expandAllSections() {
  const allSections = document.querySelectorAll(
    ".section-content:not(.active)",
  );
  const allSubsections = document.querySelectorAll(
    ".subsection-content:not(.active)",
  );
  const allSubSubsections = document.querySelectorAll(
    ".subsubsection-content:not(.active)",
  );

  allSections.forEach((section) => {
    const header = section.previousElementSibling;
    toggleSection(header);
  });

  allSubsections.forEach((subsection) => {
    const header = subsection.previousElementSibling;
    toggleSubsection(header);
  });

  allSubSubsections.forEach((subsubsection) => {
    const header = subsubsection.previousElementSibling;
    toggleSubSubsection(header);
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
      target.classList.contains("subsection-header") ||
      target.classList.contains("subsubsection-header")
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
        } else if (target.classList.contains("subsection-header")) {
          toggleSubsection(target);
        } else if (target.classList.contains("subsubsection-header")) {
          toggleSubSubsection(target);
        }
      }
    }
  });
});