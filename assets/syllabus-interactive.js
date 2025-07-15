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
 * 
 * HOW IT WORKS:
 * 1. Find the content div that follows the clicked header
 * 2. Check if it's currently open (has 'active' class)
 * 3. Add/remove 'active' class which triggers CSS max-height transition
 * 4. Update the toggle icon (▼/▲) to show current state
 * 
 * @param {HTMLElement} header - The clicked section header element (passed via 'this')
 */
function toggleSection(header) {
    // nextElementSibling gets the very next HTML element at the same level
    // This MUST be the .section-content div for this to work
    const content = header.nextElementSibling;
    
    // querySelector finds the first element with class 'toggle-icon' inside the header
    // This is the ▼/▲ symbol that shows expand/collapse state
    const icon = header.querySelector('.toggle-icon');
    
    // classList.contains() checks if element has the specified CSS class
    // 'active' class is what triggers the CSS transition to show content
    if (content.classList.contains('active')) {
        // SECTION IS CURRENTLY OPEN - CLOSE IT:
        
        // Remove 'active' from content: triggers CSS transition max-height: 2000px → 0
        content.classList.remove('active');
        
        // Remove 'active' from header: changes background color back to default
        header.classList.remove('active');
        
        // Change icon to down arrow to indicate "click to expand"
        icon.textContent = '▼';
    } else {
        // SECTION IS CURRENTLY CLOSED - OPEN IT:
        
        // Add 'active' to content: triggers CSS transition max-height: 0 → 2000px
        content.classList.add('active');
        
        // Add 'active' to header: changes to darker background color
        header.classList.add('active');
        
        // Change icon to up arrow to indicate "click to collapse"
        icon.textContent = '▲';
    }
}

/**
 * Toggles the visibility of a subsection (### headings in markdown)
 * 
 * IDENTICAL LOGIC to toggleSection but operates on subsection elements
 * Subsections are nested inside sections and have lighter styling
 * 
 * @param {HTMLElement} header - The clicked subsection header element
 */
function toggleSubsection(header) {
    // Same exact logic as toggleSection, just for subsection HTML structure
    const content = header.nextElementSibling;
    const icon = header.querySelector('.toggle-icon');
    
    if (content.classList.contains('active')) {
        // Close the subsection
        content.classList.remove('active');
        header.classList.remove('active');
        icon.textContent = '▼';
    } else {
        // Open the subsection
        content.classList.add('active');
        header.classList.add('active');
        icon.textContent = '▲';
    }
}

/**
 * Optional helper function to close all sections
 * Useful if you want a "collapse all" button
 */
function collapseAllSections() {
    // querySelectorAll gets ALL elements matching the selector (not just first)
    const allSections = document.querySelectorAll('.section-content.active');
    const allSubsections = document.querySelectorAll('.subsection-content.active');
    
    // Loop through each active section and close it
    allSections.forEach(section => {
        const header = section.previousElementSibling; // Gets the header before content
        toggleSection(header);
    });
    
    // Loop through each active subsection and close it
    allSubsections.forEach(subsection => {
        const header = subsection.previousElementSibling;
        toggleSubsection(header);
    });
}

/**
 * Optional helper function to open all sections
 * Useful if you want an "expand all" button
 */
function expandAllSections() {
    const allSections = document.querySelectorAll('.section-content:not(.active)');
    const allSubsections = document.querySelectorAll('.subsection-content:not(.active)');
    
    // :not(.active) selector gets elements that DON'T have active class (closed ones)
    allSections.forEach(section => {
        const header = section.previousElementSibling;
        toggleSection(header);
    });
    
    allSubsections.forEach(subsection => {
        const header = subsection.previousElementSibling;
        toggleSubsection(header);
    });
}

/**
 * Initialize the page when DOM is fully loaded
 * 
 * DOMContentLoaded event fires when HTML is completely loaded and parsed
 * This ensures all elements exist before we try to manipulate them
 * Without this, script might run before HTML elements are created
 */
document.addEventListener('DOMContentLoaded', function() {
    // OPTIONAL: Auto-expand the first section when page loads
    // querySelector gets only the FIRST element matching the selector
    const firstSection = document.querySelector('.section-header');
    
    // Defensive programming: check if element exists before using it
    // Prevents errors if page has no sections
    if (firstSection) {
        // Automatically open the first section for better UX
        toggleSection(firstSection);
    }
    
    // OPTIONAL: Add keyboard support for accessibility
    // Allow Enter key and Space bar to trigger section toggles
    document.addEventListener('keydown', function(event) {
        // event.target is the element that has focus when key was pressed
        const target = event.target;
        
        // Check if focused element is a section or subsection header
        if (target.classList.contains('section-header') || 
            target.classList.contains('subsection-header')) {
            
            // event.key gives us the actual key pressed
            // 13 = Enter key, 32 = Space bar (for older browser support)
            if (event.key === 'Enter' || event.key === ' ' || 
                event.keyCode === 13 || event.keyCode === 32) {
                
                // Prevent default behavior (e.g., scrolling on space)
                event.preventDefault();
                
                // Trigger appropriate toggle function
                if (target.classList.contains('section-header')) {
                    toggleSection(target);
                } else {
                    toggleSubsection(target);
                }
            }
        }
    });
});

/* ===== USAGE NOTES =====

1. HTML STRUCTURE REQUIRED:
   <div class="section">
       <div class="section-header" onclick="toggleSection(this)" tabindex="0">
           Section Title
           <span class="toggle-icon">▼</span>
       </div>
       <div class="section-content">
           <div class="section-inner">
               Content goes here...
           </div>
       </div>
   </div>

2. KEY POINTS:
   - onclick="toggleSection(this)" - 'this' passes the header element to function
   - Structure must be header immediately followed by content div
   - toggle-icon span is required for visual feedback
   - tabindex="0" makes headers keyboard accessible
   - CSS handles the visual transitions, JS just toggles classes

3. CUSTOMIZATION:
   - Change auto-expand behavior in DOMContentLoaded listener
   - Add/remove keyboard support as needed
   - Modify expand/collapse all functions if you add those buttons
   - Adjust max-height values in CSS if content is very tall

4. DEBUGGING:
   - Check browser console for errors
   - Verify HTML structure matches requirements
   - Ensure CSS file is loaded before this script
   - Test that nextElementSibling finds the right content div

===== */