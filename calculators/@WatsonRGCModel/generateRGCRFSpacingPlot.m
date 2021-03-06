function generateRGCRFSpacingPlot(obj, RGCRFSpacingFunctionHandle, eccDegs, type)
    % Plot the total RGC RF density along the temporal meridian
    plot(eccDegs, RGCRFSpacingFunctionHandle(eccDegs, 'temporal meridian', type, 'deg'), ...
        'r-', 'LineWidth', obj.figurePrefs.lineWidth); hold on;
    plot(eccDegs, RGCRFSpacingFunctionHandle(eccDegs, 'superior meridian', type, 'deg'), ...
        'b-', 'LineWidth', obj.figurePrefs.lineWidth);
    plot(eccDegs, RGCRFSpacingFunctionHandle(eccDegs, 'nasal meridian', type, 'deg'), ...
        'g-', 'LineWidth', obj.figurePrefs.lineWidth);
    plot(eccDegs, RGCRFSpacingFunctionHandle(eccDegs, 'inferior meridian', type, 'deg'), ...
        'k-', 'LineWidth', obj.figurePrefs.lineWidth);
    legend({'temporal', 'superior', 'nasal', 'inferior'}, 'Location', 'NorthWest');
    xlabel('eccentricity (degs)', 'FontAngle', obj.figurePrefs.fontAngle);
    ylabel('RGC RF spacing (degs)', 'FontAngle', obj.figurePrefs.fontAngle);
    set(gca, 'XLim', [eccDegs(1) eccDegs(end)], 'YLim', [0 1.05], ...
        'XTick', eccDegs(1):eccDegs(end)/10:eccDegs(end), 'YTick', 0:0.1:1.0, ...
        'FontSize', obj.figurePrefs.fontSize);
    grid(gca, obj.figurePrefs.grid);
end