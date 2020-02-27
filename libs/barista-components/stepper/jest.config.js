module.exports = {
  name: 'stepper',
  preset: '../../../jest.config.js',
  coverageDirectory: '../../../coverage/components/stepper',
  snapshotSerializers: [
    'jest-preset-angular/build/AngularNoNgAttributesSnapshotSerializer.js',
    'jest-preset-angular/build/AngularSnapshotSerializer.js',
    'jest-preset-angular/build/HTMLCommentSerializer.js',
  ],
};