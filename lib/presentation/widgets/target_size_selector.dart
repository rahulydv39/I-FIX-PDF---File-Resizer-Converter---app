/// Target Size Selector Widget
/// Selector for fixed target file size options
library;

import 'package:flutter/material.dart';
import '../../core/constants/target_size_config.dart';
import '../../core/theme/app_colors.dart';

/// Widget for selecting target file size from fixed options
class TargetSizeSelector extends StatefulWidget {
  /// Currently selected size in KB
  final int selectedSizeKb;

  /// Callback when size is changed
  final ValueChanged<int> onSizeChanged;

  const TargetSizeSelector({
    super.key,
    required this.selectedSizeKb,
    required this.onSizeChanged,
  });

  @override
  State<TargetSizeSelector> createState() => _TargetSizeSelectorState();
}

class _TargetSizeSelectorState extends State<TargetSizeSelector> {
  late TextEditingController _customSizeController;
  String _selectedUnit = 'KB'; // KB or MB
  bool _isCustom = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _customSizeController = TextEditingController();
    _checkIfCustom();
  }

  @override
  void didUpdateWidget(TargetSizeSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSizeKb != widget.selectedSizeKb) {
      _checkIfCustom();
    }
  }

  void _checkIfCustom() {
    if (!TargetSizeConfig.availableSizesKb.contains(widget.selectedSizeKb)) {
      _isCustom = true;
      // Convert to appropriate unit for display
      if (widget.selectedSizeKb >= 1024 && widget.selectedSizeKb % 1024 == 0) {
        _selectedUnit = 'MB';
        _customSizeController.text = (widget.selectedSizeKb / 1024).round().toString();
      } else {
        _selectedUnit = 'KB';
        _customSizeController.text = widget.selectedSizeKb.toString();
      }
    } else {
      _isCustom = false;
      _customSizeController.clear();
      _errorText = null;
    }
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  void _validateAndSubmit(String value) {
    if (value.isEmpty) {
      setState(() => _errorText = 'Required');
      return;
    }

    final number = double.tryParse(value);
    if (number == null) {
      setState(() => _errorText = 'Invalid number');
      return;
    }

    int sizeKb;
    if (_selectedUnit == 'MB') {
      sizeKb = (number * 1024).round();
    } else {
      sizeKb = number.round();
    }

    if (sizeKb < 5) {
      setState(() => _errorText = 'Min 5 KB');
      return;
    }

    if (sizeKb > 5 * 1024) { // 5 MB limit
      setState(() => _errorText = 'Max 5 MB');
      return;
    }

    setState(() => _errorText = null);
    widget.onSizeChanged(sizeKb);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Size chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...TargetSizeConfig.availableSizesKb.map((sizeKb) {
              return _buildSizeChip(sizeKb);
            }),
            _buildCustomChip(),
          ],
        ),
        
        // Custom Input Field
        if (_isCustom) ...[
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _customSizeController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Target Size',
                    hintText: 'Example: 150',
                    errorText: _errorText,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    suffixIcon: _buildUnitSelector(),
                  ),
                  onChanged: _validateAndSubmit,
                ),
              ),
            ],
          ),
        ],
        
        const SizedBox(height: 12),
        
        // Helper text
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppColors.info.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.info,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _isCustom 
                      ? 'Custom size will be used for compression'
                      : 'Final size will be close to selected value',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build a size chip
  Widget _buildSizeChip(int sizeKb) {
    final isSelected = !_isCustom && widget.selectedSizeKb == sizeKb;
    
    return ChoiceChip(
      label: Text(TargetSizeConfig.getLabel(sizeKb)),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _isCustom = false;
            _errorText = null;
          });
          TargetSizeConfig.logSelection(sizeKb);
          widget.onSizeChanged(sizeKb);
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      backgroundColor: AppColors.backgroundLight,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: isSelected ? AppColors.primary : AppColors.textPrimaryDark,
        fontSize: 13,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  /// Build custom chip
  Widget _buildCustomChip() {
    return ChoiceChip(
      label: const Text('Custom'),
      selected: _isCustom,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _isCustom = true;
            _customSizeController.clear();
          });
        }
      },
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      backgroundColor: AppColors.backgroundLight,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: _isCustom ? AppColors.primary : AppColors.textPrimaryDark,
        fontSize: 13,
      ),
      side: BorderSide(
        color: _isCustom ? AppColors.primary : Colors.transparent,
        width: 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildUnitSelector() {
    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildUnitOption('KB'),
          _buildUnitOption('MB'),
        ],
      ),
    );
  }

  Widget _buildUnitOption(String unit) {
    final isSelected = _selectedUnit == unit;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUnit = unit;
          if (_customSizeController.text.isNotEmpty) {
            _validateAndSubmit(_customSizeController.text);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          unit,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppColors.primary : AppColors.textSecondaryDark,
          ),
        ),
      ),
    );
  }
}
